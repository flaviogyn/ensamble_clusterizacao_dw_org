import pandas as pd
import numpy as np

from sqlalchemy import create_engine, text

from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score


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
# 2. LER OS DADOS DO DATA MART
# ============================================================

sql = """
SELECT
    id_cliente_dw,
    recencia_dias,
    frequencia_compras,
    quantidade_itens,
    valor_total,
    ticket_medio,
    produtos_distintos,
    categorias_distintas
FROM dm_vendas.vw_cliente_clusterizacao
"""

clientes = pd.read_sql(sql, engine)

print("Quantidade de clientes:", len(clientes))

print("\nPrimeiros registros:")
print(clientes.head())

# ============================================================
# 3. VERIFICAR DADOS AUSENTES
# ============================================================

print("\nValores nulos:")
print(clientes.isnull().sum())

# ============================================================
# 4. SELECIONAR AS VARIÁVEIS PARA O K-MEANS
# ============================================================

features = [
    "recencia_dias",
    "frequencia_compras",
    "quantidade_itens",
    "valor_total",
    "ticket_medio",
    "produtos_distintos",
    "categorias_distintas"
]

X = clientes[features].copy()

# ============================================================
# 5. TRATAMENTO DE VALORES AUSENTES
# ============================================================

X = X.replace([np.inf, -np.inf], np.nan)

X = X.dropna()

# Manter somente os clientes que permaneceram após o tratamento
clientes = clientes.loc[X.index].copy()


# ============================================================
# 6. NORMALIZAÇÃO DOS DADOS
# ============================================================

scaler = StandardScaler()

X_scaled = scaler.fit_transform(X)

# ============================================================
# 7. TESTAR DIFERENTES QUANTIDADES DE CLUSTERS
# ============================================================

resultados = []

for k in range(2, 8):

    modelo = KMeans(
        n_clusters=k,
        random_state=42,
        n_init=10
    )

    labels = modelo.fit_predict(X_scaled)

    silhouette = silhouette_score(
        X_scaled,
        labels
    )

    resultados.append({
        "k": k,
        "silhouette": silhouette
    })


resultado_k = pd.DataFrame(resultados)

print("\nSilhouette Score:")
print(resultado_k)

# ============================================================
# 8. ESCOLHER O MELHOR K
# ============================================================

melhor_k = int(
    resultado_k.loc[
        resultado_k["silhouette"].idxmax(),
        "k"
    ]
)

print("\nMelhor número de clusters:", melhor_k)


# ============================================================
# 9. EXECUTAR O K-MEANS DEFINITIVO
# ============================================================

kmeans = KMeans(
    n_clusters=melhor_k,
    random_state=42,
    n_init=10
)

clientes["cluster"] = kmeans.fit_predict(X_scaled)


# ============================================================
# 10. VER RESULTADO DA CLUSTERIZAÇÃO
# ============================================================

print("\nClientes classificados:")
print(
    clientes[
        [
            "id_cliente_dw",
            "cluster"
        ]
    ].head(20)
)


# ============================================================
# 11. ANALISAR O TAMANHO DOS CLUSTERS
# ============================================================

print("\nQuantidade de clientes por cluster:")

print(
    clientes["cluster"]
    .value_counts()
    .sort_index()
)


# ============================================================
# 12. ANALISAR O PERFIL DOS CLUSTERS
# ============================================================

perfil_clusters = (
    clientes
    .groupby("cluster")[features]
    .mean()
    .round(2)
)

print("\nPerfil médio dos clusters:")
print(perfil_clusters)


# ============================================================
# 13. CRIAR A TABELA DE DESTINO
# ============================================================

sql_create_table = """

CREATE TABLE IF NOT EXISTS dm_vendas.cliente_cluster (
    id_cliente_dw BIGINT PRIMARY KEY,
    cluster INTEGER NOT NULL,
    data_processamento TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP
);

"""

with engine.begin() as connection:
    connection.execute(
        text(sql_create_table)
    )

# ============================================================
# 14. PREPARAR OS DADOS PARA GRAVAÇÃO
# ============================================================

clusters_gravar = clientes[
    [
        "id_cliente_dw",
        "cluster"
    ]
].copy()


# ============================================================
# 15. GRAVAR OS CLUSTERS NO POSTGRESQL
# ============================================================

sql_insert = """
INSERT INTO dm_vendas.cliente_cluster
(
    id_cliente_dw,
    cluster,
    data_processamento
)
VALUES
(
    :id_cliente_dw,
    :cluster,
    CURRENT_TIMESTAMP
)
ON CONFLICT (id_cliente_dw)
DO UPDATE SET
    cluster = EXCLUDED.cluster,
    data_processamento = CURRENT_TIMESTAMP;
"""

with engine.begin() as connection:
    for _, row in clusters_gravar.iterrows():
        connection.execute(
            text(sql_insert),
            {
                "id_cliente_dw": int(
                    row["id_cliente_dw"]
                ),
                "cluster": int(
                    row["cluster"]
                )
            }
        )

# ============================================================
# 16. CONFIRMAR A GRAVAÇÃO
# ============================================================

sql_verificacao = """
SELECT
    cluster,
    COUNT(*) AS quantidade_clientes
FROM dm_vendas.cliente_cluster
GROUP BY cluster
ORDER BY cluster;
"""

resultado = pd.read_sql(
    sql_verificacao,
    engine
)

print("\nClusters gravados no PostgreSQL:")
print(resultado)


# ============================================================
# 17. FINAL
# ============================================================

print("\nProcesso concluído!")

print(
    "Os clusters foram calculados pelo K-Means "
    "e gravados em dm_vendas.cliente_cluster."
)