"""
ATIVIDADE - DW ORGANIZACIONAL
Clusterização de clientes com SOM + Regras de Associação por cluster.

Fluxo:
    PostgreSQL
      -> dm_clientes.fato_cliente_mes
      -> agregação histórica por cliente
      -> padronização
      -> SOM (Self-Organizing Map)
      -> K-Means sobre os neurônios da SOM
      -> cluster de cada cliente
      -> dw.fato_venda_item + dw.dim_produto
      -> cestas de compras por cluster
      -> Apriori
      -> regras de associação

Saídas:
    resultados_som_associacao/
      clientes_clusters.csv
      perfil_clusters.csv
      regras_cluster_*.csv
      itemsets_cluster_*.csv
      bmu_clientes.csv
      som_umatrix.png
      som_clusters.png
      silhouette_clusters.png

Antes de executar:
    1. Instale as dependências:
       pip install -r requirements_atividade_som.txt
    2. Ajuste DB_USER, DB_PASSWORD, DB_HOST, DB_PORT e DB_NAME.
    3. Execute:
       python main_som.py
"""

from pathlib import Path
import warnings

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from sqlalchemy import create_engine, text
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from minisom import MiniSom

from mlxtend.preprocessing import TransactionEncoder
from mlxtend.frequent_patterns import apriori, association_rules


# ============================================================
# 1. CONFIGURAÇÃO
# ============================================================

DB_USER = "postgres"
DB_PASSWORD = "1234"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "postgres"

# Tamanho do mapa SOM.
SOM_X = 5
SOM_Y = 5

# Número de iterações do treinamento da SOM.
SOM_ITERATIONS = 2000

# Reprodutibilidade.
RANDOM_SEED = 42

# Número de clusters finais.
# Se AUTO_SELECT_K = True, o código testa os valores abaixo.
AUTO_SELECT_K = True
K_MIN = 2
K_MAX = 5
N_CLUSTERS = 3

# Parâmetros das regras de associação.
MIN_SUPPORT = 0.05
MIN_CONFIDENCE = 0.30
MIN_LIFT = 1.00
MAX_ITEMSET_SIZE = 3

# Para evitar regras muito pequenas/ruidosas, exige pelo menos
# este número de transações no cluster.
MIN_TRANSACTIONS_CLUSTER = 5

OUTPUT_DIR = Path("resultados_som_associacao")
OUTPUT_DIR.mkdir(exist_ok=True)


# ============================================================
# 2. CONEXÃO
# ============================================================

def criar_engine():
    if DB_PASSWORD == "SUA_SENHA":
        raise ValueError(
            "Altere DB_PASSWORD no início do arquivo antes de executar."
        )

    url = (
        f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    return create_engine(url)


# ============================================================
# 3. EXTRAÇÃO DO DATA MART DE CLIENTES
# ============================================================

SQL_CLIENTES = """
SELECT
    f.sk_cliente,
    c.id_cliente_origem,
    c.sistema_origem,
    c.nome_cliente,

    SUM(f.quantidade_vendas)::INTEGER AS quantidade_vendas,
    SUM(f.quantidade_itens)::INTEGER AS quantidade_itens,
    SUM(f.quantidade_produtos)::INTEGER AS quantidade_produtos,
    SUM(f.valor_total)::NUMERIC(15,2) AS valor_total,

    CASE
        WHEN SUM(f.quantidade_vendas) > 0
        THEN SUM(f.valor_total) / SUM(f.quantidade_vendas)
        ELSE 0
    END AS ticket_medio,

    COUNT(*)::INTEGER AS meses_com_compra

FROM dm_clientes.fato_cliente_mes f
INNER JOIN dm_clientes.dim_cliente c
    ON c.sk_cliente = f.sk_cliente

GROUP BY
    f.sk_cliente,
    c.id_cliente_origem,
    c.sistema_origem,
    c.nome_cliente

ORDER BY f.sk_cliente;
"""


def carregar_clientes(engine):
    df = pd.read_sql(text(SQL_CLIENTES), engine)

    if df.empty:
        raise ValueError(
            "A consulta de clientes não retornou registros."
        )

    return df


# ============================================================
# 4. PREPARAÇÃO DOS DADOS PARA A SOM
# ============================================================

FEATURES = [
    "quantidade_vendas",
    "quantidade_itens",
    "quantidade_produtos",
    "valor_total",
    "ticket_medio",
]


def preparar_features(df):
    dados = df.copy()

    dados[FEATURES] = dados[FEATURES].apply(
        pd.to_numeric,
        errors="coerce"
    )

    dados[FEATURES] = dados[FEATURES].replace(
        [np.inf, -np.inf],
        np.nan
    )

    dados = dados.dropna(subset=FEATURES).reset_index(drop=True)

    # Log transforma variáveis muito assimétricas, como valor_total.
    # O +1 evita log(0).
    LOG_FEATURES = [
        "quantidade_vendas",
        "quantidade_itens",
        "quantidade_produtos",
        "valor_total",
        "ticket_medio",
    ]

    for col in LOG_FEATURES:
        dados[col] = np.log1p(dados[col].clip(lower=0))

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(dados[FEATURES])

    return dados, X_scaled, scaler


# ============================================================
# 5. TREINAMENTO DA SOM
# ============================================================

def treinar_som(X_scaled):
    som = MiniSom(
        x=SOM_X,
        y=SOM_Y,
        input_len=X_scaled.shape[1],
        sigma=max(SOM_X, SOM_Y) / 2,
        learning_rate=0.5,
        neighborhood_function="gaussian",
        random_seed=RANDOM_SEED,
    )

    som.random_weights_init(X_scaled)

    som.train_random(
        X_scaled,
        num_iteration=SOM_ITERATIONS,
    )

    return som


# ============================================================
# 6. BMU DOS CLIENTES
# ============================================================

def obter_bmus(som, X_scaled):
    bmus = np.array([
        som.winner(x)
        for x in X_scaled
    ])

    return bmus


# ============================================================
# 7. SELEÇÃO DO NÚMERO DE CLUSTERS
# ============================================================

def selecionar_k(som):
    weights = som.get_weights()
    weights_2d = weights.reshape(-1, weights.shape[-1])

    resultados = []

    max_k = min(K_MAX, len(weights_2d) - 1)

    for k in range(K_MIN, max_k + 1):
        km = KMeans(
            n_clusters=k,
            random_state=RANDOM_SEED,
            n_init=20
        )

        labels = km.fit_predict(weights_2d)

        score = silhouette_score(
            weights_2d,
            labels
        )

        resultados.append({
            "k": k,
            "silhouette": score
        })

    df_scores = pd.DataFrame(resultados)
    df_scores.to_csv(
        OUTPUT_DIR / "silhouette_clusters.csv",
        index=False
    )

    if AUTO_SELECT_K:
        melhor_k = int(
            df_scores.loc[
                df_scores["silhouette"].idxmax(),
                "k"
            ]
        )
    else:
        melhor_k = N_CLUSTERS

    return melhor_k, df_scores


# ============================================================
# 8. CLUSTERIZAÇÃO DOS NEURÔNIOS DA SOM
# ============================================================

def clusterizar_neuronios(som, n_clusters):
    weights = som.get_weights()
    weights_2d = weights.reshape(-1, weights.shape[-1])

    kmeans = KMeans(
        n_clusters=n_clusters,
        random_state=RANDOM_SEED,
        n_init=20
    )

    neuron_labels = kmeans.fit_predict(weights_2d)

    return neuron_labels, kmeans


def bmu_para_indice(bmu):
    x, y = bmu
    return int(x * SOM_Y + y)


def atribuir_clusters(df, bmus, neuron_labels):
    resultado = df.copy()

    indices = [
        bmu_para_indice(bmu)
        for bmu in bmus
    ]

    resultado["bmu_x"] = bmus[:, 0]
    resultado["bmu_y"] = bmus[:, 1]
    resultado["cluster"] = [
        int(neuron_labels[i])
        for i in indices
    ]

    return resultado


# ============================================================
# 9. EXTRAÇÃO DAS TRANSAÇÕES
# ============================================================

SQL_TRANSACOES = """
SELECT
    f.sk_cliente,
    f.sistema_origem,
    f.id_venda_origem,
    f.sk_produto,
    p.nome_produto,

    -- Uma venda pode ter produtos diferentes.
    -- O identificador da cesta inclui o sistema para evitar
    -- colisões entre Northwind e Mercearia.
    (f.sistema_origem || '_' || COALESCE(f.id_venda_origem, f.id_order_origem)::TEXT) AS transacao_id

FROM dw.fato_venda_item f
INNER JOIN dw.dim_produto p
    ON p.sk_produto = f.sk_produto

WHERE f.quantidade > 0

ORDER BY
    f.sistema_origem,
    f.id_venda_origem,
    f.sk_produto;
"""


def carregar_transacoes(engine):
    df = pd.read_sql(
        text(SQL_TRANSACOES),
        engine
    )

    if df.empty:
        raise ValueError(
            "A consulta de transações não retornou registros."
        )

    return df


# ============================================================
# 10. ASSOCIAR CLUSTER ÀS TRANSAÇÕES
# ============================================================

def anexar_clusters_transacoes(df_transacoes, df_clientes):
    mapa_clusters = df_clientes[
        ["sk_cliente", "cluster"]
    ].drop_duplicates()

    resultado = df_transacoes.merge(
        mapa_clusters,
        on="sk_cliente",
        how="inner"
    )

    if resultado.empty:
        raise ValueError(
            "Nenhuma transação foi associada a um cliente clusterizado."
        )

    return resultado


# ============================================================
# 11. CESTAS
# ============================================================

def construir_cestas(df_cluster):
    """
    Retorna:
        transacoes_ids: lista de IDs de transação
        cestas: lista de listas de produtos

    Usa sk_produto para identificar o item de forma inequívoca,
    mas mantém nome_produto para apresentação.
    """

    base = df_cluster.copy()

    # Uma mesma venda pode conter o mesmo produto em mais de uma
    # linha dependendo da origem; elimina duplicação dentro da cesta.
    base = base.drop_duplicates(
        subset=["transacao_id", "sk_produto"]
    )

    # Representação do produto para o Apriori:
    # "SK | nome" evita colisões entre produtos de mesmo nome.
    base["produto"] = (
        base["sk_produto"].astype(str)
        + " | "
        + base["nome_produto"].astype(str)
    )

    agrupado = (
        base.groupby("transacao_id")["produto"]
        .apply(list)
        .reset_index()
    )

    return agrupado["transacao_id"].tolist(), agrupado["produto"].tolist()


# ============================================================
# 12. APRIORI POR CLUSTER
# ============================================================

def executar_apriori_por_cluster(df_transacoes, cluster):
    dados = df_transacoes[
        df_transacoes["cluster"] == cluster
    ].copy()

    transacoes_ids, cestas = construir_cestas(dados)

    if len(cestas) < MIN_TRANSACTIONS_CLUSTER:
        print(
            f"[AVISO] Cluster {cluster}: "
            f"{len(cestas)} transações. "
            f"Menor que o mínimo de "
            f"{MIN_TRANSACTIONS_CLUSTER}. "
            f"Regras podem ser pouco confiáveis."
        )

    if not cestas:
        return pd.DataFrame(), pd.DataFrame()

    encoder = TransactionEncoder()

    matriz = encoder.fit(cestas).transform(cestas)

    basket = pd.DataFrame(
        matriz,
        columns=encoder.columns_
    )

    frequent_itemsets = apriori(
        basket,
        min_support=MIN_SUPPORT,
        use_colnames=True,
        max_len=MAX_ITEMSET_SIZE
    )

    if frequent_itemsets.empty:
        return frequent_itemsets, pd.DataFrame()

    rules = association_rules(
        frequent_itemsets,
        metric="confidence",
        min_threshold=MIN_CONFIDENCE
    )

    if rules.empty:
        return frequent_itemsets, rules

    rules = rules[
        rules["lift"] >= MIN_LIFT
    ].copy()

    rules = rules.sort_values(
        by=["lift", "confidence", "support"],
        ascending=False
    )

    return frequent_itemsets, rules


# ============================================================
# 13. FORMATAÇÃO DAS REGRAS
# ============================================================

def formatar_itemset(itemset):
    return ", ".join(sorted(map(str, itemset)))


def salvar_regras(cluster, frequent_itemsets, rules):
    itemsets = frequent_itemsets.copy()

    if not itemsets.empty:
        itemsets["itemsets"] = itemsets["itemsets"].apply(
            formatar_itemset
        )

        itemsets.to_csv(
            OUTPUT_DIR / f"itemsets_cluster_{cluster}.csv",
            index=False
        )

    if not rules.empty:
        regras = rules.copy()

        regras["antecedents"] = regras["antecedents"].apply(
            formatar_itemset
        )

        regras["consequents"] = regras["consequents"].apply(
            formatar_itemset
        )

        colunas = [
            "antecedents",
            "consequents",
            "antecedent support",
            "consequent support",
            "support",
            "confidence",
            "lift",
        ]

        colunas_existentes = [
            c for c in colunas
            if c in regras.columns
        ]

        regras = regras[colunas_existentes]

        regras.to_csv(
            OUTPUT_DIR / f"regras_cluster_{cluster}.csv",
            index=False
        )

    return


# ============================================================
# 14. PERFIL DOS CLUSTERS
# ============================================================

def gerar_perfil_clusters(df_clientes):
    perfil = (
        df_clientes
        .groupby("cluster")[FEATURES]
        .agg(["count", "mean", "median"])
    )

    perfil.to_csv(
        OUTPUT_DIR / "perfil_clusters.csv"
    )

    return perfil


# ============================================================
# 15. VISUALIZAÇÕES
# ============================================================

def plotar_umatrix(som):
    plt.figure(figsize=(8, 6))

    plt.imshow(
        som.distance_map().T,
        cmap="bone_r",
        interpolation="nearest"
    )

    plt.colorbar(label="Distância média aos neurônios vizinhos")
    plt.title("U-Matrix da SOM")
    plt.xlabel("X do mapa SOM")
    plt.ylabel("Y do mapa SOM")

    plt.tight_layout()
    plt.savefig(
        OUTPUT_DIR / "som_umatrix.png",
        dpi=150
    )
    plt.close()


def plotar_clusters_som(som, neuron_labels):
    matriz = neuron_labels.reshape(SOM_X, SOM_Y)

    plt.figure(figsize=(8, 6))

    plt.imshow(
        matriz.T,
        cmap="tab10",
        interpolation="nearest"
    )

    plt.colorbar(label="Cluster")
    plt.title("Clusters dos neurônios da SOM")
    plt.xlabel("X do mapa SOM")
    plt.ylabel("Y do mapa SOM")

    plt.tight_layout()
    plt.savefig(
        OUTPUT_DIR / "som_clusters.png",
        dpi=150
    )
    plt.close()


def plotar_silhouette(df_scores):
    plt.figure(figsize=(7, 5))

    plt.plot(
        df_scores["k"],
        df_scores["silhouette"],
        marker="o"
    )

    plt.title("Silhouette Score por número de clusters")
    plt.xlabel("Número de clusters")
    plt.ylabel("Silhouette Score")
    plt.xticks(df_scores["k"])

    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    plt.savefig(
        OUTPUT_DIR / "silhouette_score.png",
        dpi=150
    )
    plt.close()


# ============================================================
# 16. RELATÓRIO TEXTUAL NO CONSOLE
# ============================================================

def imprimir_resumo(df_clientes, df_transacoes, df_scores):
    print("\n" + "=" * 70)
    print("RESUMO DA EXECUÇÃO")
    print("=" * 70)

    print(
        f"Clientes clusterizados: {df_clientes['sk_cliente'].nunique()}"
    )

    print(
        f"Transações consideradas: "
        f"{df_transacoes['transacao_id'].nunique()}"
    )

    print(
        f"Itens de venda considerados: {len(df_transacoes)}"
    )

    print("\nDistribuição dos clientes:")
    print(
        df_clientes["cluster"]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print("\nSilhouette dos K testados:")
    print(df_scores.to_string(index=False))

    print("\nResultados salvos em:")
    print(OUTPUT_DIR.resolve())

    print("=" * 70)


# ============================================================
# 17. MAIN
# ============================================================

def main():
    warnings.filterwarnings(
        "ignore",
        category=FutureWarning
    )

    print("=" * 70)
    print("ATIVIDADE: SOM + REGRAS DE ASSOCIAÇÃO")
    print("=" * 70)

    engine = criar_engine()

    # --------------------------------------------------------
    # A. CLIENTES
    # --------------------------------------------------------
    print("\n[1/8] Carregando clientes...")
    df_clientes_raw = carregar_clientes(engine)

    print(
        f"      {len(df_clientes_raw)} clientes encontrados."
    )

    # --------------------------------------------------------
    # B. PREPARAÇÃO
    # --------------------------------------------------------
    print("\n[2/8] Preparando variáveis...")
    df_clientes, X_scaled, scaler = preparar_features(
        df_clientes_raw
    )

    print(
        f"      Variáveis utilizadas: {', '.join(FEATURES)}"
    )

    # --------------------------------------------------------
    # C. SOM
    # --------------------------------------------------------
    print("\n[3/8] Treinando SOM...")
    som = treinar_som(X_scaled)

    bmus = obter_bmus(
        som,
        X_scaled
    )

    # --------------------------------------------------------
    # D. K SOBRE NEURÔNIOS
    # --------------------------------------------------------
    print("\n[4/8] Selecionando número de clusters...")
    n_clusters, df_scores = selecionar_k(som)

    print(
        f"      Número de clusters escolhido: {n_clusters}"
    )

    neuron_labels, kmeans = clusterizar_neuronios(
        som,
        n_clusters
    )

    df_clientes = atribuir_clusters(
        df_clientes,
        bmus,
        neuron_labels
    )

    # --------------------------------------------------------
    # E. SALVAR CLIENTES
    # --------------------------------------------------------
    df_clientes.to_csv(
        OUTPUT_DIR / "clientes_clusters.csv",
        index=False
    )

    bmu_clientes = df_clientes[
        [
            "sk_cliente",
            "nome_cliente",
            "bmu_x",
            "bmu_y",
            "cluster"
        ]
    ]

    bmu_clientes.to_csv(
        OUTPUT_DIR / "bmu_clientes.csv",
        index=False
    )

    perfil = gerar_perfil_clusters(
        df_clientes
    )

    # --------------------------------------------------------
    # F. VISUALIZAÇÕES SOM
    # --------------------------------------------------------
    plotar_umatrix(som)
    plotar_clusters_som(
        som,
        neuron_labels
    )
    plotar_silhouette(
        df_scores
    )

    # --------------------------------------------------------
    # G. TRANSAÇÕES
    # --------------------------------------------------------
    print("\n[5/8] Carregando transações...")
    df_transacoes = carregar_transacoes(engine)

    print(
        f"      {df_transacoes['transacao_id'].nunique()} "
        f"transações encontradas."
    )

    df_transacoes = anexar_clusters_transacoes(
        df_transacoes,
        df_clientes
    )

    df_transacoes.to_csv(
        OUTPUT_DIR / "transacoes_com_clusters.csv",
        index=False
    )

    # --------------------------------------------------------
    # H. APRIORI POR CLUSTER
    # --------------------------------------------------------
    print("\n[6/8] Executando regras de associação...")

    clusters = sorted(
        df_transacoes["cluster"].unique()
    )

    resumo_regras = []

    for cluster in clusters:
        print(
            f"      Cluster {cluster}..."
        )

        itemsets, rules = executar_apriori_por_cluster(
            df_transacoes,
            cluster
        )

        salvar_regras(
            cluster,
            itemsets,
            rules
        )

        resumo_regras.append({
            "cluster": int(cluster),
            "quantidade_itemsets": len(itemsets),
            "quantidade_regras": len(rules),
        })

    resumo = pd.DataFrame(resumo_regras)

    resumo.to_csv(
        OUTPUT_DIR / "resumo_regras.csv",
        index=False
    )

    # --------------------------------------------------------
    # I. RESUMO
    # --------------------------------------------------------
    print("\n[7/8] Gerando resumo...")
    imprimir_resumo(
        df_clientes,
        df_transacoes,
        df_scores
    )

    print("\n[8/8] Concluído.")
    print(
        "      Consulte a pasta resultados_som_associacao/"
    )


if __name__ == "__main__":
    main()
