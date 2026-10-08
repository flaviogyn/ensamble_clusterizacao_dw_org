import pandas as pd
import numpy as np

from sqlalchemy import create_engine
from sqlalchemy import text

from mlxtend.preprocessing import TransactionEncoder
from mlxtend.frequent_patterns import apriori, association_rules

# ============================================================
# 1. CONFIGURAÇÃO DO POSTGRESQL
# ============================================================

DB_USER = "postgres"
DB_PASSWORD = "1234"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "postgres"

DATABASE_URL = (
    f"postgresql+psycopg2://"
    f"{DB_USER}:{DB_PASSWORD}@"
    f"{DB_HOST}:{DB_PORT}/"
    f"{DB_NAME}"
)

engine = create_engine(DATABASE_URL)

# ============================================================
# 2. LER OS DADOS DA VIEW
# ============================================================

sql = """
SELECT
    cluster,
    id_cliente_dw,
    id_transacao,
    id_produto_dw,
    produto,
    categoria,
    quantidade,
    valor_liquido
FROM dm_vendas.vw_compras_por_cluster
ORDER BY cluster, id_cliente_dw, id_transacao;
"""

df = pd.read_sql(sql, engine)


print("\n" + "=" * 70)
print("DADOS CARREGADOS")
print("=" * 70)

print(df.head())

print(f"\nTotal de registros: {len(df)}")

print("\nClusters encontrados:")
print(sorted(df["cluster"].unique()))


# ============================================================
# 3. VALIDAÇÃO
# ============================================================

colunas_obrigatorias = [
    "cluster",
    "id_cliente_dw",
    "id_transacao",
    "id_produto_dw",
    "produto",
    "categoria",
    "quantidade",
    "valor_liquido"
]

for coluna in colunas_obrigatorias:

    if coluna not in df.columns:

        raise ValueError(
            f"A coluna '{coluna}' não existe na view."
        )


# Remover registros sem informações necessárias
df = df.dropna(
    subset=[
        "cluster",
        "id_transacao",
        "produto"
    ]
)

df["cluster"] = df["cluster"].astype(int)


# ============================================================
# 4. PARÂMETROS DO APRIORI
# ============================================================

# Produto/conjunto precisa aparecer em pelo menos
# 5% das transações do cluster.

MIN_SUPPORT = 0.05

# Pelo menos 30% das transações que possuem
# o antecedente devem possuir o consequente.

MIN_CONFIDENCE = 0.30

# Consideraremos apenas associações positivas.

MIN_LIFT = 1.00


# ============================================================
# 5. FUNÇÃO APRIORI
# ============================================================

def executar_apriori_cluster(df_cluster, cluster_id):

    print("\n")
    print("=" * 70)
    print(f"ANÁLISE DO CLUSTER {cluster_id}")
    print("=" * 70)

    # --------------------------------------------------------
    # Clientes
    # --------------------------------------------------------

    quantidade_clientes = (
        df_cluster["id_cliente_dw"]
        .nunique()
    )

    print(
        f"Clientes: {quantidade_clientes}"
    )

    # --------------------------------------------------------
    # Transações
    # --------------------------------------------------------

    quantidade_transacoes = (
        df_cluster["id_transacao"]
        .nunique()
    )

    print(
        f"Transações: {quantidade_transacoes}"
    )

    # --------------------------------------------------------
    # Produtos
    # --------------------------------------------------------

    quantidade_produtos = (
        df_cluster["id_produto_dw"]
        .nunique()
    )

    print(
        f"Produtos diferentes: {quantidade_produtos}"
    )

    # --------------------------------------------------------
    # Criar as cestas
    #
    # Cada id_transacao representa uma cesta.
    # --------------------------------------------------------

    transacoes = (
        df_cluster
        .groupby("id_transacao")["produto"]
        .apply(lambda x: list(set(x)))
        .tolist()
    )

    print(
        f"Cestas criadas: {len(transacoes)}"
    )

    # Não é possível fazer uma associação
    # significativa com menos de 2 transações.

    if len(transacoes) < 2:

        print(
            "Cluster possui poucas transações."
        )

        return None

    # --------------------------------------------------------
    # Transformar as cestas em matriz binária
    # --------------------------------------------------------

    te = TransactionEncoder()

    matriz = te.fit(
        transacoes
    ).transform(
        transacoes
    )

    df_transacoes = pd.DataFrame(
        matriz,
        columns=te.columns_
    )

    print(
        f"Colunas de produtos na matriz: "
        f"{len(df_transacoes.columns)}"
    )

    # --------------------------------------------------------
    # APRIORI
    # --------------------------------------------------------

    frequent_itemsets = apriori(
        df_transacoes,
        min_support=MIN_SUPPORT,
        use_colnames=True
    )

    if frequent_itemsets.empty:

        print(
            f"Nenhum conjunto frequente encontrado "
            f"com suporte >= {MIN_SUPPORT:.2f}"
        )

        return None

    # --------------------------------------------------------
    # Quantidade de itens no conjunto
    # --------------------------------------------------------

    frequent_itemsets["tamanho"] = (
        frequent_itemsets["itemsets"]
        .apply(len)
    )

    # --------------------------------------------------------
    # Converter conjunto de produtos para texto
    # --------------------------------------------------------

    frequent_itemsets["produtos"] = (
        frequent_itemsets["itemsets"]
        .apply(
            lambda x: ", ".join(
                sorted(x)
            )
        )
    )

    # --------------------------------------------------------
    # REGRAS DE ASSOCIAÇÃO
    # --------------------------------------------------------

    regras = association_rules(
        frequent_itemsets,
        metric="confidence",
        min_threshold=MIN_CONFIDENCE
    )

    if regras.empty:

        print(
            f"Nenhuma regra encontrada "
            f"com confiança >= {MIN_CONFIDENCE:.2f}"
        )

        return None

    # --------------------------------------------------------
    # FILTRO PELO LIFT
    # --------------------------------------------------------

    regras = regras[
        regras["lift"] >= MIN_LIFT
    ].copy()

    if regras.empty:

        print(
            f"Nenhuma regra encontrada "
            f"com lift >= {MIN_LIFT:.2f}"
        )

        return None

    # --------------------------------------------------------
    # Transformar conjuntos em texto
    # --------------------------------------------------------

    regras["antecedentes"] = (
        regras["antecedents"]
        .apply(
            lambda x: ", ".join(
                sorted(x)
            )
        )
    )

    regras["consequentes"] = (
        regras["consequents"]
        .apply(
            lambda x: ", ".join(
                sorted(x)
            )
        )
    )

    # --------------------------------------------------------
    # Informações do cluster
    # --------------------------------------------------------

    regras["cluster"] = cluster_id

    regras["quantidade_clientes"] = (
        quantidade_clientes
    )

    regras["quantidade_transacoes"] = (
        quantidade_transacoes
    )

    # --------------------------------------------------------
    # Selecionar as informações importantes
    # --------------------------------------------------------

    resultado = regras[
        [
            "cluster",
            "quantidade_clientes",
            "quantidade_transacoes",
            "antecedentes",
            "consequentes",
            "support",
            "confidence",
            "lift"
        ]
    ].copy()

    # --------------------------------------------------------
    # Ordenação
    #
    # Primeiro as associações com maior lift,
    # depois maior confiança e suporte.
    # --------------------------------------------------------

    resultado = resultado.sort_values(
        by=[
            "lift",
            "confidence",
            "support"
        ],
        ascending=False
    )

    # --------------------------------------------------------
    # RESULTADOS DO CLUSTER
    # --------------------------------------------------------

    print("\nConjuntos frequentes:")

    print(
        frequent_itemsets[
            [
                "produtos",
                "tamanho",
                "support"
            ]
        ]
        .sort_values(
            by="support",
            ascending=False
        )
        .head(20)
        .to_string(index=False)
    )

    print("\nRegras de associação:")

    print(
        resultado
        .head(20)
        .to_string(index=False)
    )

    return resultado


# ============================================================
# 6. EXECUTAR PARA TODOS OS CLUSTERS
# ============================================================

todos_resultados = []

clusters = sorted(
    df["cluster"].unique()
)

for cluster_id in clusters:

    df_cluster = df[
        df["cluster"] == cluster_id
    ].copy()

    resultado = executar_apriori_cluster(
        df_cluster,
        cluster_id
    )

    if resultado is not None:

        todos_resultados.append(
            resultado
        )


# ============================================================
# 7. CONSOLIDAR AS REGRAS
# ============================================================

if todos_resultados:

    df_regras = pd.concat(
        todos_resultados,
        ignore_index=True
    )

else:

    df_regras = pd.DataFrame()


# ============================================================
# 8. RESULTADO FINAL
# ============================================================

print("\n")
print("=" * 70)
print("RESULTADO FINAL DA DESCOBERTA DE ASSOCIAÇÃO")
print("=" * 70)

if df_regras.empty:

    print(
        "Nenhuma regra de associação foi encontrada."
    )

else:

    print(
        f"Total de regras encontradas: "
        f"{len(df_regras)}"
    )

    print("\nTop 30 regras:")

    print(
        df_regras
        .head(30)
        .to_string(index=False)
    )


# ============================================================
# 9. SALVAR RESULTADOS
# ============================================================

if not df_regras.empty:

    df_regras.to_csv(
        "regras_associacao_por_cluster.csv",
        index=False,
        encoding="utf-8-sig"
    )

    print(
        "\nArquivo gerado:"
        " regras_associacao_por_cluster.csv"
    )

# ============================================================
# 10. SALVAR NO BANCO DE DADOS (ESTRELA DE VENDAS)
# ============================================================

def gravar_no_banco(df_regras):

    print("\n" + "="*70)
    print("GRAVANDO NO BANCO DE DADOS")
    print("="*70)

    if df_regras.empty:
        print("Nenhuma regra para gravar.")
        return

    # --------------------------------------------------------
    # Criar tabela se não existir
    # --------------------------------------------------------

    sql_create = """
    CREATE TABLE IF NOT EXISTS dm_vendas.regras_associacao(
        id_regra SERIAL PRIMARY KEY,
        cluster INTEGER NOT NULL,
        quantidade_clientes BIGINT,
        quantidade_transacoes INTEGER,
        antecedentes TEXT NOT NULL,
        consequentes TEXT NOT NULL,
        support DECIMAL(5,4) NOT NULL,
        confidence DECIMAL(5,4) NOT NULL,
        lift DECIMAL(10,4) NOT NULL,
        data_processamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """

    with engine.begin() as conn:
        conn.execute(text(sql_create))

    print("Tabela dm_vendas.regras_associacao verificada.")

    # --------------------------------------------------------
    # Transformar DataFrame para INSERT
    # --------------------------------------------------------

    regras_insert = df_regras[[
        "cluster",
        "quantidade_clientes",
        "quantidade_transacoes",
        "antecedentes",
        "consequentes",
        "support",
        "confidence",
        "lift"
    ]].copy()

    # --------------------------------------------------------
    # Inserir dados
    # --------------------------------------------------------

    sql_insert = """
    INSERT INTO dm_vendas.regras_associacao(
        cluster,
        quantidade_clientes,
        quantidade_transacoes,
        antecedentes,
        consequentes,
        support,
        confidence,
        lift,
        data_processamento
    ) VALUES (
        :cluster,
        :quantidade_clientes,
        :quantidade_transacoes,
        :antecedentes,
        :consequentes,
        :support,
        :confidence,
        :lift,
        CURRENT_TIMESTAMP
    );
    """

    with engine.begin() as conn:
        for _, row in regras_insert.iterrows():
            conn.execute(text(sql_insert), row.to_dict())

    print(f"{len(regras_insert)} regras gravadas com sucesso.")


# ============================================================
# 11. EXECUTAR GRAVAÇÃO NO BANCO
# ============================================================

gravar_no_banco(df_regras)