#!/usr/bin/env python3
"""Executa consultas de leitura na coleção de teste de hinos."""

from __future__ import annotations

import argparse
import os


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--colecao", default="hinos_teste", help="coleção consultada (padrão: hinos_teste)"
    )
    args = parser.parse_args()

    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        raise SystemExit("GOOGLE_APPLICATION_CREDENTIALS não está definida.")

    try:
        import firebase_admin
        from firebase_admin import firestore
        from google.cloud.firestore_v1.base_query import FieldFilter
    except ImportError as erro:
        raise SystemExit(
            "Pacote ausente. Instale com: python -m pip install firebase-admin"
        ) from erro

    firebase_admin.initialize_app()
    banco = firestore.client()
    colecao = banco.collection(args.colecao)

    print(f"Coleção consultada: {args.colecao}\n")

    # 1. Busca direta pelo ID do documento.
    documento_60 = colecao.document("CC_060").get()
    assert documento_60.exists, "CC_060 não foi encontrado."
    cc_060 = documento_60.to_dict()
    print(
        "1. BUSCA POR ID: OK\n"
        f"   {cc_060['id']} — {cc_060['titulo']} — tom {cc_060['tom']}\n"
    )

    # 2. Busca pelo mesmo obraId, que deve retornar CC_060 e VM_024.
    mesma_obra = list(
        colecao.where(filter=FieldFilter("obraId", "==", cc_060["obraId"])).stream()
    )
    ids_mesma_obra = sorted(doc.id for doc in mesma_obra)
    assert ids_mesma_obra == ["CC_060", "VM_024"], (
        f"Correspondência inesperada para CC_060: {ids_mesma_obra}"
    )
    print("2. CORRESPONDENTE POR obraId: OK")
    for documento in mesma_obra:
        hino = documento.to_dict()
        print(f"   {hino['id']} — {hino['titulo']} — tom {hino['tom']}")
    print()

    # 3. Um obraId exclusivo deve retornar somente o próprio VM_025.
    documento_25 = colecao.document("VM_025").get()
    assert documento_25.exists, "VM_025 não foi encontrado."
    vm_025 = documento_25.to_dict()
    obra_isolada = list(
        colecao.where(filter=FieldFilter("obraId", "==", vm_025["obraId"])).stream()
    )
    ids_obra_isolada = [doc.id for doc in obra_isolada]
    assert ids_obra_isolada == ["VM_025"], (
        f"VM_025 deveria estar sozinho, mas retornou: {ids_obra_isolada}"
    )
    print("3. HINO SEM CORRESPONDENTE: OK")
    print("   VM_025 retornou somente o próprio documento.\n")

    # 4. Pesquisa por assunto usando array_contains.
    por_salvacao = list(
        colecao.where(filter=FieldFilter("assuntos", "array_contains", "SALVAÇÃO")).stream()
    )
    ids_salvacao = sorted(doc.id for doc in por_salvacao)
    assert "VM_081" in ids_salvacao, "VM_081 não apareceu no assunto SALVAÇÃO."
    print("4. BUSCA POR ASSUNTO: OK")
    for documento in por_salvacao:
        hino = documento.to_dict()
        print(f"   {hino['id']} — {hino['titulo']}")
    print()

    # 5. Consulta pelos campos usados na escolha de livro e número.
    por_livro_numero = list(
        colecao.where(filter=FieldFilter("livro", "==", "CC"))
        .where(filter=FieldFilter("numero", "==", 60))
        .stream()
    )
    ids_livro_numero = [doc.id for doc in por_livro_numero]
    assert ids_livro_numero == ["CC_060"], (
        f"Consulta CC + 60 retornou: {ids_livro_numero}"
    )
    print("5. BUSCA POR LIVRO E NÚMERO: OK")
    print("   CC + 60 retornou CC_060.\n")

    print("TODOS OS TESTES PASSARAM. Nenhum documento foi modificado.")


if __name__ == "__main__":
    main()
