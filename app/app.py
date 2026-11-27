# source .venv/bin/activate
# python app/app.py

import os
from pathlib import Path

import psycopg


def carregar_env():
    env = Path(__file__).resolve().parent.parent / ".env"
    if env.exists():
        for linha in env.read_text(encoding="utf-8").splitlines():
            linha = linha.strip()
            if linha and not linha.startswith("#") and "=" in linha:
                chave, valor = linha.split("=", 1)
                os.environ.setdefault(chave.strip(), valor.strip())


def conectar():
    carregar_env()
    return psycopg.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        options="-c timezone=America/Fortaleza",
    )


try:
    conexao = conectar()
except Exception as erro:
    print("Não consegui conectar no banco. Confira o arquivo .env:", erro)
    exit()

cursor = conexao.cursor()
print("Conectado no banco", os.getenv("DB_NAME"), "como", os.getenv("DB_USER"))

while True:
    print()
    print("===== RESERVA DE SALAS =====")
    print("1 - Ver agenda de uma sala")
    print("2 - Criar reserva")
    print("3 - Cancelar reserva")
    print("4 - Relatório de ocupação do mês")
    print("0 - Sair")
    opcao = input("Escolha uma opção: ")

    try:
        if opcao == "1":
            sala = input("ID da sala: ")
            dia = input("Dia (AAAA-MM-DD): ")

            cursor.execute(
                "SELECT reserva_id, inicio, fim, responsavel, qtd_pessoas, status "
                "FROM v_agenda_dia WHERE sala_id = %s AND dia = %s ORDER BY inicio",
                (sala, dia),
            )
            linhas = cursor.fetchall()

            if len(linhas) == 0:
                print("Nenhuma reserva nesse dia.")
            else:
                print("Reserva | Início | Fim | Responsável | Pessoas | Status")
                for linha in linhas:
                    print(linha[0], "|", linha[1], "|", linha[2], "|", linha[3], "|", linha[4], "|", linha[5])
            conexao.commit()

        elif opcao == "2":
            usuario = input("Seu ID de usuário: ")
            sala = input("ID da sala: ")
            dia = input("Dia (AAAA-MM-DD): ")
            hora_inicio = input("Hora de início (HH:MM): ")
            hora_fim = input("Hora de término (HH:MM): ")
            pessoas = input("Quantidade de pessoas: ")

            inicio = dia + " " + hora_inicio
            fim = dia + " " + hora_fim

            cursor.execute(
                "SELECT criar_reserva(%s, %s, %s, %s, %s)",
                (usuario, sala, inicio, fim, pessoas),
            )
            id_reserva = cursor.fetchone()[0]
            conexao.commit()
            print("Reserva criada! Número da reserva:", id_reserva)

        elif opcao == "3":
            usuario = input("Seu ID de usuário: ")
            reserva = input("ID da reserva: ")

            cursor.execute("SELECT cancelar_reserva(%s, %s)", (reserva, usuario))
            conexao.commit()
            print("Reserva cancelada!")

        elif opcao == "4":
            mes = input("Mês (AAAA-MM): ")

            cursor.execute(
                "SELECT sala, tipo, total_reservas, horas_reservadas, taxa_ocupacao_pct "
                "FROM mv_ocupacao_mensal WHERE mes = %s ORDER BY taxa_ocupacao_pct DESC",
                (mes + "-01",),
            )
            linhas = cursor.fetchall()

            if len(linhas) == 0:
                print("Não tem dados para esse mês.")
            else:
                print("Sala | Tipo | Reservas | Horas | Ocupação (%)")
                for linha in linhas:
                    print(linha[0], "|", linha[1], "|", linha[2], "|", linha[3], "|", linha[4])
            conexao.commit()

        elif opcao == "0":
            print("Saindo...")
            break

        else:
            print("Opção inválida!")

    except psycopg.Error as erro:
        conexao.rollback()
        print("Erro:", erro.diag.message_primary)

cursor.close()
conexao.close()