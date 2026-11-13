#!/usr/bin/env python3
"""Recupera arquivos locais a partir de um state privado, sem imprimir segredos."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def attributes(state, resource_type):
    return [
        instance.get("attributes", {})
        for resource in state.get("resources", [])
        if resource.get("mode") == "managed" and resource.get("type") == resource_type
        for instance in resource.get("instances", [])
        if not instance.get("deposed")
    ]


def recover(state, destination, account, region):
    clusters = attributes(state, "aws_eks_cluster")
    databases = attributes(state, "aws_db_instance")
    expected_arn = f"arn:aws:eks:{region}:{account}:cluster/toggle-cluster"
    if clusters and any(cluster.get("arn") != expected_arn for cluster in clusters):
        raise ValueError("State pertence a outro cluster, conta ou regiao.")
    pending = {}
    if databases:
        passwords = [db.get("password") for db in databases]
        if any(not isinstance(p, str) or len(p) < 16 for p in passwords):
            raise ValueError("State tem RDS sem senha recuperavel; interrompido para evitar troca de senha.")
        if len(set(passwords)) != 1:
            raise ValueError("Os bancos tem senhas diferentes; requer revisao antes do plano.")
        pending["rds-password"] = passwords[0]
    if clusters and databases:
        engines = {db.get("engine_version") for db in databases}
        eks = clusters[0].get("version")
        if len(engines) != 1 or not all(isinstance(v, str) and v for v in engines) or not eks:
            raise ValueError("Versoes existentes inconsistentes no state.")
        pending["versions.json"] = json.dumps({"eks": eks, "postgres": next(iter(engines))})
    destination.mkdir(parents=True, exist_ok=True)
    destination.chmod(0o700)
    # Confere todos os arquivos antes de escrever; nunca substitui senha divergente.
    for name, content in pending.items():
        target = destination / name
        if target.exists() and target.stat().st_size:
            existing = target.read_text()
            equal = json.loads(existing) == json.loads(content) if name.endswith(".json") else existing == content
            if not equal:
                raise ValueError(f"Arquivo {name} difere do state; interrompido sem substituir.")
    for name, content in pending.items():
        target = destination / name
        if not target.exists() or not target.stat().st_size:
            with tempfile.NamedTemporaryFile(mode="w", dir=destination, delete=False) as stream:
                temporary = Path(stream.name)
                os.chmod(temporary, 0o600)
                stream.write(content)
            temporary.replace(target)
        target.chmod(0o600)
    return bool(databases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("state", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("account")
    parser.add_argument("region")
    args = parser.parse_args()
    try:
        found = recover(json.loads(args.state.read_text()), args.destination, args.account, args.region)
    except (ValueError, OSError, KeyError, TypeError):
        # Nao imprime excecoes de parsing que poderiam incluir conteudo sensivel.
        raise SystemExit("Nao foi possivel recuperar os arquivos locais com seguranca. Nenhum plano foi aplicado.")
    print("Arquivos locais conferidos/recuperados do state existente." if found else "State ainda sem RDS; configuracao inicial sera preparada.")


if __name__ == "__main__":
    main()
