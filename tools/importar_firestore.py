#!/usr/bin/env python3
"""Valida e importa hinos JSON para uma coleção do Cloud Firestore."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


CAMPOS_OBRIGATORIOS = {
    "id",
    "obraId",
    "livro",
    "numero",
    "numeroFormatado",
    "titulo",
    "tom",
    "assuntos",
    "estrofes",
    "tituloNormalizado",
    "textoBusca",
}


def carregar_e_validar(caminho: Path) -> list[dict]:
    with caminho.open("r", encoding="utf-8") as arquivo:
        hinos = json.load(arquivo)

    if not isinstance(hinos, list) or not hinos:
        raise ValueError("O arquivo deve conter uma lista não vazia de hinos.")

    ids: set[str] = set()
    for posicao, hino in enumerate(hinos, start=1):
        if not isinstance(hino, dict):
            raise ValueError(f"Item {posicao} não é um objeto JSON.")
        faltantes = CAMPOS_OBRIGATORIOS - set(hino)
        extras = set(hino) - CAMPOS_OBRIGATORIOS
        if faltantes:
            raise ValueError(f"{hino.get('id', posicao)} sem campos: {sorted(faltantes)}")
        if extras:
            raise ValueError(f"{hino['id']} possui campos inesperados: {sorted(extras)}")
        if hino["id"] in ids:
            raise ValueError(f"ID duplicado: {hino['id']}")
        ids.add(hino["id"])
        if hino["livro"] not in {"CC", "VM"}:
            raise ValueError(f"Livro inválido em {hino['id']}: {hino['livro']}")
        if hino["id"] != f"{hino['livro']}_{hino['numeroFormatado']}":
            raise ValueError(f"ID incompatível com livro/número: {hino['id']}")
        if hino["numero"] != int(hino["numeroFormatado"]):
            raise ValueError(f"Número incompatível em {hino['id']}")
        if not hino["estrofes"] or not hino["assuntos"]:
            raise ValueError(f"Letra ou assunto vazio em {hino['id']}")

    return hinos


def importar(hinos: list[dict], colecao: str) -> None:
    try:
        import firebase_admin
        from firebase_admin import firestore
    except ImportError as erro:
        raise SystemExit(
            "Pacote ausente. Instale com: python -m pip install firebase-admin"
        ) from erro

    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        raise SystemExit(
            "Defina GOOGLE_APPLICATION_CREDENTIALS com o caminho da chave da conta de serviço."
        )

    firebase_admin.initialize_app()
    banco = firestore.client()

    # Mantém cada lote abaixo do limite máximo e funciona também na carga completa.
    tamanho_lote = 400
    gravados = 0
    for inicio in range(0, len(hinos), tamanho_lote):
        lote = banco.batch()
        parte = hinos[inicio : inicio + tamanho_lote]
        for hino in parte:
            referencia = banco.collection(colecao).document(hino["id"])
            lote.set(referencia, hino)
        lote.commit()
        gravados += len(parte)
        print(f"Gravados: {gravados}/{len(hinos)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("arquivo", type=Path, help="JSON transformado de hinos")
    parser.add_argument(
        "--colecao", default="hinos_teste", help="coleção de destino (padrão: hinos_teste)"
    )
    parser.add_argument(
        "--executar", action="store_true", help="confirma que os documentos serão gravados"
    )
    args = parser.parse_args()

    if "/" in args.colecao or not args.colecao.strip():
        raise SystemExit("Informe somente o nome de uma coleção válida.")
    if args.colecao == "hinos":
        raise SystemExit("A coleção 'hinos' está protegida neste importador de teste.")

    hinos = carregar_e_validar(args.arquivo)
    print(f"Arquivo válido: {len(hinos)} hinos.")
    print(f"Coleção de destino: {args.colecao}")

    if not args.executar:
        print("SIMULAÇÃO: nenhuma conexão foi aberta e nenhum documento foi gravado.")
        print("Acrescente --executar somente quando estiver pronto para importar.")
        return

    importar(hinos, args.colecao)
    print("Importação concluída.")


if __name__ == "__main__":
    main()
