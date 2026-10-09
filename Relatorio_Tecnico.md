# Relatório Técnico — Clusterização de Clientes e Regras de Associação

## 1. Identificação do Projeto

**Projeto:** Data Warehouse Organizacional — Mercearia + Northwind  
**Data Mart utilizado:** `dm_vendas`  
**Técnicas de Data Mining:** K-Means e Regras de Associação com Apriori  
**Banco de dados:** PostgreSQL  
**Linguagem:** Python  
**Bibliotecas principais:** Pandas, NumPy, Scikit-learn, MLxtend e SQLAlchemy

---

## 2. Objetivo

O objetivo deste trabalho é aplicar técnicas de mineração de dados sobre o Data Warehouse Organizacional, utilizando o Data Mart de Vendas para:

1. **Clusterizar/classificar clientes** de acordo com seu comportamento de compra;
2. Utilizar os grupos de clientes obtidos na clusterização;
3. Aplicar **Regras de Descoberta de Associação** sobre os produtos comprados por cada grupo;
4. Identificar padrões de compra específicos dos diferentes segmentos de clientes.

O processo foi estruturado como uma sequência integrada:

```text
Data Warehouse
      |
      v
Data Mart de Vendas
      |
      v
Características dos Clientes
      |
      v
K-Means
      |
      v
Clusters de Clientes
      |
      v
Compras por Cluster
      |
      v
Apriori
      |
      v
Regras de Associação
```

Dessa forma, a etapa de associação não é executada sobre todos os clientes indistintamente. Ela utiliza os grupos identificados pelo algoritmo de clusterização.

---

# 3. Arquitetura dos Dados

O projeto utiliza uma abordagem de **Data Warehouse Organizacional**, integrando informações provenientes das bases Mercearia e Northwind.

O Data Warehouse Organizacional funciona como camada integrada dos dados, enquanto os Data Marts disponibilizam informações específicas para determinados assuntos.

Neste trabalho, o Data Mart utilizado é:

```text
dm_vendas
```

O Data Mart possui uma modelagem dimensional em estrela, contendo dimensões e uma tabela fato de vendas.

---

# 4. Data Mart de Vendas

O Data Mart `dm_vendas` contém, entre outras, as seguintes estruturas:

### Dimensão de clientes

```text
dm_vendas.dim_cliente
```

Principais atributos:

- `id_cliente_dw`
- `id_pessoa`
- `origem_principal`
- `nome`
- `empresa`
- `cidade`
- `regiao`
- `estado`
- `pais`
- `tipo_cliente`

### Dimensão de produtos

```text
dm_vendas.dim_produto
```

Principais atributos:

- `id_produto_dw`
- `id_produto`
- `origem_principal`
- `produto`
- `categoria`

### Fato de vendas

```text
dm_vendas.fato_vendas
```

Principais medidas e identificadores:

- `id_fato_venda_dw`
- `id_tempo`
- `id_cliente_dw`
- `id_produto_dw`
- `quantidade`
- `valor_unitario`
- `valor_bruto`
- `valor_desconto`
- `valor_liquido`
- `frete`
- `id_origem_registro`
- `sistema_origem`

A granularidade da fato de vendas é de item de venda/pedido. Portanto, uma transação pode possuir várias linhas de produtos.

Essa característica é especialmente importante para a etapa de Regras de Associação, pois o algoritmo precisa reconstruir cada compra como uma cesta contendo os produtos adquiridos conjuntamente.

---

# 5. Etapa 1 — Preparação dos Dados para Clusterização

Foi criada a visão:

```text
dm_vendas.vw_cliente_clusterizacao
```

Essa visão consolida o comportamento histórico dos clientes e produz as características utilizadas pelo algoritmo de clusterização.

As principais variáveis comportamentais utilizadas foram:

| Variável | Descrição |
|---|---|
| `recencia_dias` | Quantidade de dias desde a última compra |
| `frequencia_compras` | Quantidade de transações realizadas |
| `quantidade_itens` | Quantidade total de itens comprados |
| `valor_total` | Valor total comprado |
| `ticket_medio` | Valor médio por transação |
| `produtos_distintos` | Quantidade de produtos diferentes comprados |
| `categorias_distintas` | Quantidade de categorias diferentes compradas |

Essas variáveis procuram representar diferentes dimensões do comportamento de consumo.

---

# 6. Características Utilizadas no K-Means

## 6.1 Recência

A variável `recencia_dias` representa o tempo decorrido desde a última compra do cliente.

Quanto menor a recência, mais recentemente o cliente realizou uma compra.

Exemplo:

```text
Cliente A → 5 dias
Cliente B → 120 dias
```

O Cliente A apresenta comportamento de compra mais recente.

---

## 6.2 Frequência

A variável `frequencia_compras` representa a quantidade de transações realizadas pelo cliente.

Clientes com frequência elevada apresentam maior recorrência de compra.

---

## 6.3 Quantidade de itens

A variável `quantidade_itens` representa a quantidade acumulada de itens comprados pelo cliente.

---

## 6.4 Valor total

A variável `valor_total` representa o valor financeiro total das compras realizadas pelo cliente.

Essa variável permite diferenciar clientes com maior e menor contribuição financeira.

---

## 6.5 Ticket médio

O `ticket_medio` representa o valor médio das transações do cliente.

É calculado como:

```text
ticket_medio =
valor_total / frequencia_compras
```

---

## 6.6 Diversidade de produtos

A variável `produtos_distintos` representa a quantidade de produtos diferentes adquiridos pelo cliente.

---

## 6.7 Diversidade de categorias

A variável `categorias_distintas` representa a quantidade de categorias diferentes de produtos adquiridas.

---

# 7. Normalização dos Dados

Antes da aplicação do K-Means, as variáveis são padronizadas utilizando `StandardScaler` do Scikit-learn.

O objetivo é colocar as variáveis em uma escala comparável.

Isso é importante porque as características possuem unidades e amplitudes diferentes.

Por exemplo:

```text
valor_total       → pode estar na ordem de milhares
frequencia        → pode estar na ordem de dezenas
recencia_dias     → pode estar na ordem de centenas
produtos_distintos → pode estar na ordem de dezenas
```

Sem padronização, uma variável de grande magnitude poderia exercer influência excessiva sobre a distância utilizada pelo K-Means.

---

# 8. Algoritmo K-Means

O K-Means foi utilizado para segmentar os clientes em grupos de comportamento semelhante.

O algoritmo procura dividir os clientes em `K` grupos de forma que os elementos pertencentes a um mesmo grupo apresentem características semelhantes.

O processo pode ser resumido em:

1. Definir o número de clusters;
2. Inicializar os centroides;
3. Associar cada cliente ao centroide mais próximo;
4. Recalcular os centroides;
5. Repetir até a convergência.

---

# 9. Escolha da Quantidade de Clusters

Foram testados diferentes valores de `K`, por exemplo:

```text
K = 2
K = 3
K = 4
K = 5
K = 6
K = 7
```

Para avaliar a qualidade dos agrupamentos foi utilizado o **Silhouette Score**.

O valor do Silhouette Score é utilizado para verificar simultaneamente:

- proximidade de um elemento em relação aos elementos do próprio cluster;
- distância em relação aos outros clusters.

Quanto maior o valor, em geral, melhor a separação dos grupos.

O código seleciona o valor de `K` que apresenta o maior Silhouette Score entre os valores avaliados.

---

# 10. Persistência dos Clusters

Depois da execução do K-Means, os clusters calculados em Python são armazenados no PostgreSQL.

Foi criada a tabela:

```sql
dm_vendas.cliente_cluster
```

Estrutura:

```sql
CREATE TABLE IF NOT EXISTS dm_vendas.cliente_cluster (
    id_cliente_dw BIGINT PRIMARY KEY,
    cluster INTEGER NOT NULL,
    data_processamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

A tabela estabelece a relação:

```text
Cliente → Cluster
```

Exemplo conceitual:

```text
id_cliente_dw | cluster
--------------+--------
1             | 0
2             | 1
3             | 0
4             | 2
5             | 1
```

Essa persistência é importante porque permite utilizar o resultado da mineração de dados em consultas SQL posteriores.

# 11. Etapa 2 — Compras por Cluster

Depois da classificação dos clientes, foi criada a visão analítica:

```text
dm_vendas.vw_compras_por_cluster
```

A estrutura da visão reúne os clientes classificados pelo K-Means, suas vendas e os respectivos produtos:

```text
cluster
id_cliente_dw
id_transacao
id_produto_dw
produto
categoria
quantidade
valor_liquido
```

### Implementação SQL da View

Para permitir a reconstrução correta das cestas de compra (Market Basket Analysis), a view foi construída integrando a fato do Data Mart com o DW Organizacional:

```sql
CREATE OR REPLACE VIEW dm_vendas.vw_compras_por_cluster AS
SELECT
    cc.cluster,
    fv.id_cliente_dw,
    
    -- Identificador unificado da cesta (Pedido/Venda) por sistema de origem:
    (fv.sistema_origem || '_' || COALESCE(dw.id_venda, dw.id_order)::TEXT)::VARCHAR(100) AS id_transacao,
    
    fv.id_produto_dw,
    dp.produto,
    dp.categoria,
    fv.quantidade,
    fv.valor_liquido
FROM dm_vendas.cliente_cluster cc
INNER JOIN dm_vendas.fato_vendas fv
    ON fv.id_cliente_dw = cc.id_cliente_dw
INNER JOIN dw_organizacional.fato_vendas dw
    ON dw.id_fato_venda_dw = fv.id_fato_venda_dw
INNER JOIN dm_vendas.dim_produto dp
    ON dp.id_produto_dw = fv.id_produto_dw;
```

---

# 12. Importância do `id_transacao` e Agrupamento da Cesta

O campo `id_transacao` é o elemento central para a descoberta de associação. Ele define a fronteira da **cesta de compra** (Market Basket).

### 12.1 Granularidade de Cesta vs. Granularidade de Linha
A tabela fato armazena dados na granularidade de **item de venda** (1 produto por linha). Se utilizássemos o identificador da linha da tabela fato como transação, cada cesta conteria exatamente 1 produto (`len(cesta) == 1`), impossibilitando matematicamente o algoritmo Apriori de encontrar regras de coocorrência (já que regras exigem pelo menos 2 produtos em uma mesma transação).

A solução unifica a transação no nível do cabeçalho do pedido:
- **Mercearia:** utiliza `dw.id_venda` (100 vendas reais agrupando os 1.000 itens, resultando em média de 10 produtos por cesta).
- **Northwind:** utiliza `dw.id_order` (830 pedidos reais agrupando os 2.155 itens, com média de 2 a 3 produtos por cesta).

### 12.2 Prevenção de Colisão entre Sistemas (`sistema_origem`)
Como os bancos relacionais de origem (Mercearia e Northwind) possuem numerações de pedidos independentes, o pedido `10` da Mercearia poderia colidir com o pedido `10` da Northwind. A concatenação com `fv.sistema_origem` (ex.: `'MERCEARIA_10'` e `'NORTHWIND_10'`) assegura unicidade global em todo o Data Mart.

No Python, o Apriori agrupa todas as linhas com o mesmo `id_transacao` em uma lista de produtos únicos:

```python
transacoes = (
    df_cluster
    .groupby("id_transacao")["produto"]
    .apply(lambda x: list(set(x)))
    .tolist()
)
```

Por exemplo, a transação `MERCEARIA_51` converte-se em:

```python
["Detergente 500ml - Marca A", "Agua Mineral 1.5L - Marca C", "Agua Sanitaria 1L - Marca E", "Cafe 500g - Marca D", ...]
```

Essa lista forma a cesta utilizada para calcular o suporte de itemsets compostos.

# 13. Etapa 3 — Apriori

O algoritmo Apriori é utilizado para descobrir conjuntos de produtos que aparecem frequentemente juntos nas transações.

O processamento é realizado separadamente para cada cluster.

A lógica é:

```text
Cluster 0
    |
    +--> Transações do Cluster 0
    |
    +--> Apriori
    |
    +--> Regras do Cluster 0


Cluster 1
    |
    +--> Transações do Cluster 1
    |
    +--> Apriori
    |
    +--> Regras do Cluster 1


Cluster 2
    |
    +--> Transações do Cluster 2
    |
    +--> Apriori
    |
    +--> Regras do Cluster 2
```

Essa abordagem permite descobrir padrões específicos de cada segmento de clientes.

---

# 14. Construção da Matriz de Transações

A biblioteca MLxtend disponibiliza o `TransactionEncoder` para converter as cestas em uma matriz binária.

Exemplo:

```text
              Arroz  Feijão  Café  Leite
Venda 1          1      1      0      0
Venda 2          1      0      1      0
Venda 3          0      1      0      1
Venda 4          0      0      1      1
```

O valor:

```text
1
```

indica que o produto está presente na transação.

O valor:

```text
0
```

indica que o produto não está presente.

Essa matriz é utilizada pelo algoritmo Apriori.

---

# 15. Suporte

O **suporte** representa a frequência de ocorrência de um conjunto de produtos dentro das transações.

Foi utilizado inicialmente:

```python
MIN_SUPPORT = 0.05
```

Isso significa que o conjunto precisa aparecer em pelo menos 5% das transações do respectivo cluster.

Exemplo:

```text
support = 0.30
```

significa que 30% das transações possuem aquele conjunto de produtos.

---

# 16. Confiança

A **confiança** mede a probabilidade de o consequente aparecer quando o antecedente aparece.

Foi utilizado:

```python
MIN_CONFIDENCE = 0.30
```

Exemplo:

```text
Arroz → Feijão
confidence = 0.75
```

Interpretação:

> Entre as transações que possuem Arroz, 75% também possuem Feijão.

---

# 17. Lift

O **Lift** permite verificar se a associação observada é maior do que aquela que seria esperada considerando as frequências individuais dos produtos.

Foi utilizado:

```python
MIN_LIFT = 1.00
```

Interpretação:

```text
Lift < 1
    Associação negativa

Lift = 1
    Ausência de associação relevante

Lift > 1
    Associação positiva
```

Por exemplo:

```text
Arroz → Feijão
Lift = 1.50
```

indica que a ocorrência conjunta é 1,5 vezes maior do que seria esperado caso os produtos fossem independentes.

---

# 18. Geração das Regras

Após a identificação dos conjuntos frequentes, o algoritmo `association_rules` gera as regras.

Cada regra possui, entre outras, as informações:

```text
antecedents
consequents
support
confidence
lift
```

Para facilitar a interpretação, os conjuntos de produtos são convertidos para texto.

Exemplo:

```text
Antecedente:
Arroz

Consequente:
Feijão
```

resultando na regra:

```text
Arroz → Feijão
```

---

# 19. Ordenação das Regras

As regras são ordenadas priorizando:

1. maior `lift`;
2. maior `confidence`;
3. maior `support`.

Assim, as primeiras regras apresentadas tendem a ser aquelas com maior força de associação.

---

# 20. Resultado Consolidado

Ao final do processamento, as regras encontradas em todos os clusters são consolidadas em um único DataFrame:

```text
df_regras
```

A estrutura final contém:

| Campo | Descrição |
|---|---|
| `cluster` | Grupo de clientes |
| `quantidade_clientes` | Número de clientes no cluster |
| `quantidade_transacoes` | Número de transações do cluster |
| `antecedentes` | Produtos que formam o antecedente |
| `consequentes` | Produto(s) consequente(s) |
| `support` | Suporte da regra |
| `confidence` | Confiança da regra |
| `lift` | Força da associação |

---

# 21. Exportação e Persistência dos Resultados

As regras de associação descobertas pelo pipeline são armazenadas em duas mídias distintas: arquivo para consumo analítico e banco de dados relacional para persistência no Data Mart.

### 21.1 Exportação em CSV
As regras são salvas no arquivo:

```text
regras_associacao_por_cluster.csv
```

Esse arquivo contém o detalhamento completo de todas as regras, seus antecedentes, consequentes e métricas associadas.

### 21.2 Gravação no Banco de Dados (Data Mart de Vendas)
Para garantir a rastreabilidade e permitir a integração direta com ferramentas de BI (Power BI, Metabase) ou sistemas de recomendação em tempo real, as regras são persistidas na tabela:

```sql
dm_vendas.regras_associacao
```

Estrutura da tabela no PostgreSQL:

```sql
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
```

Na execução definitiva, todas as **3.804 regras** foram gravadas com sucesso nesta tabela.

---

# 22. Interpretação de Regras Reais

Considere uma das principais regras descobertas no Cluster 0:

```text
Cluster: 0
Antecedente: {Achocolatado 400g - Marca A, Agua Sanitaria 1L - Marca E}
Consequente: {Agua Mineral 1.5L - Marca C}

Support: 0.16 (16%)
Confidence: 1.00 (100%)
Lift: 5.00
```

### Análise Prática:
1. **Suporte (16%):** Em 16% de todas as cestas do Cluster 0, esses três produtos foram comprados simultaneamente.
2. **Confiança (100%):** Em todas as transações em que o cliente comprou Achocolatado e Água Sanitária, ele **sempre** incluiu também a Água Mineral na mesma cesta.
3. **Lift (5,00):** A probabilidade de compra da Água Mineral na presença do par antecedente é **5 vezes maior** do que a compra isolada da Água Mineral. Trata-se de uma associação positiva extremamente forte.

### Aplicações de Negócio:
- **Promoções Cruzadas:** Desconto no Achocolatado com incentivo à compra de Água Mineral.
- **Layout de Gôndola:** Posicionamento estratégico ou criação de kits promocionais para o segmento específico.
- **Mecanismo de Recomendação:** Sugestão automática no checkout para clientes classificados no Cluster 0.

---

# 23. Relação entre Clusterização e Associação

A principal característica do processo desenvolvido é a utilização encadeada das duas técnicas.

O K-Means identifica grupos de clientes com comportamentos semelhantes.

Em seguida, o Apriori analisa o comportamento de compra dentro de cada grupo.

Portanto:

```text
K-Means
   |
   | identifica
   v
Segmentos de clientes
   |
   | direcionam
   v
Transações por segmento
   |
   | analisadas por
   v
Apriori
   |
   v
Padrões de associação
```

Essa abordagem permite obter informações mais específicas do que uma análise de associação realizada sobre todos os clientes simultaneamente.

---

# 24. Resultados Reais da Descoberta de Associação

A execução do pipeline analítico sobre a base de dados integrada produziu os seguintes resultados consolidados:

### 24.1 Resumo Geral por Cluster

| Cluster | Origem Predominante | Clientes | Transações (Cestas) | Produtos Distintos | Produtos com Suporte >= 5% | Regras Encontradas |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0** | Mercearia | 100 | 100 | 100 | 40 | **3.804** |
| **1** | Northwind | 39 | 478 | 77 | 15 | 0 |
| **2** | Northwind | 3 | 89 | 74 | 27 | 0 |
| **3** | Northwind | 47 | 263 | 76 | 8 | 0 |
| **Total** | - | **189** | **930** | - | - | **3.804** |

### 24.2 Top 20 Regras de Associação Descobertas (Cluster 0)

Todas as regras abaixo foram descobertas com **Suporte = 16%**, **Confiança = 100% (1.00)** e **Lift = 5.00**:

| # | Antecedentes | Consequentes | Suporte | Confiança | Lift |
| :---: | :---|---| :---: | :---: | :---: |
| 1 | Achocolatado 400g - Marca A, Agua Sanitaria 1L - Marca E | Agua Mineral 1.5L - Marca C | 0,16 | 1,00 | 5,00 |
| 2 | Acucar 1kg - Marca C, Desinfetante 1L - Marca D | Creme Dental 90g - Marca A | 0,16 | 1,00 | 5,00 |
| 3 | Agua Mineral 1.5L - Marca C, Escova Dental - Marca B | Agua Sanitaria 1L - Marca E | 0,16 | 1,00 | 5,00 |
| 4 | Agua Sanitaria 1L - Marca E, Cafe 500g - Marca D | Escova Dental - Marca B | 0,16 | 1,00 | 5,00 |
| 5 | Amaciante 2L - Marca C, Feijao Carioca 1kg - Marca B | Condicionador 350ml - Marca E | 0,16 | 1,00 | 5,00 |
| 6 | Condicionador 350ml - Marca E, Iogurte Natural - Marca A | Amaciante 2L - Marca C | 0,16 | 1,00 | 5,00 |
| 7 | Amaciante 2L - Marca C, Sardinha 125g - Marca D | Iogurte Natural - Marca A | 0,16 | 1,00 | 5,00 |
| 8 | Arroz 5kg - Marca A, Sabao em Po 1kg - Marca B | Shampoo 350ml - Marca D | 0,16 | 1,00 | 5,00 |
| 9 | Atum 170g - Marca E, Desinfetante 1L - Marca D | Refrigerante 2L - Marca B | 0,16 | 1,00 | 5,00 |
| 10 | Cerveja 350ml - Marca E, Esponja 3un - Marca D | Papel Toalha 2un - Marca B | 0,16 | 1,00 | 5,00 |
| 11 | Manteiga 200g - Marca C, Papel Toalha 2un - Marca B | Cerveja 350ml - Marca E | 0,16 | 1,00 | 5,00 |
| 12 | Creme Dental 90g - Marca A, Refrigerante 2L - Marca B | Desinfetante 1L - Marca D | 0,16 | 1,00 | 5,00 |
| 13 | Leite Integral 1L - Marca E, Papel Higienico 4un - Marca A | Desodorante - Marca C | 0,16 | 1,00 | 5,00 |
| 14 | Desodorante - Marca C, Suco de Uva 1L - Marca D | Papel Higienico 4un - Marca A | 0,16 | 1,00 | 5,00 |
| 15 | Queijo Mussarela 500g - Marca D, Sabonete 90g - Marca C | Detergente 500ml - Marca A | 0,16 | 1,00 | 5,00 |
| 16 | Detergente 500ml - Marca A, Saco de Lixo 30L - Marca E | Sabonete 90g - Marca C | 0,16 | 1,00 | 5,00 |
| 17 | Oleo de Soja 900ml - Marca A, Papel Toalha 2un - Marca B | Esponja 3un - Marca D | 0,16 | 1,00 | 5,00 |
| 18 | Macarrao Espaguete 500g - Marca B, Sabonete 90g - Marca C | Saco de Lixo 30L - Marca E | 0,16 | 1,00 | 5,00 |
| 19 | Margarina 500g - Marca B, Papel Higienico 4un - Marca A | Suco de Uva 1L - Marca D | 0,16 | 1,00 | 5,00 |
| 20 | Presunto 500g - Marca E, Shampoo 350ml - Marca D | Sabao em Po 1kg - Marca B | 0,16 | 1,00 | 5,00 |

### 24.3 Discussão Técnica dos Resultados por Cluster

* **Cluster 0 (Clientes Mercearia):**  
  Apresenta cestas de compras compostas (exatamente 10 itens por cesta), com catálogo de 100 produtos concentrados em 40 itens de alta rotatividade (cada um aparecendo em 30% das transações). Essa densidade permite a descoberta de itemsets frequentes triplos e gera regras de coocorrência perfeitas (confiança 100% e lift 5,0).

* **Clusters 1, 2 e 3 (Clientes Northwind):**  
  Nenhum par de produtos atingiu o limiar de `MIN_SUPPORT = 0.05` e `MIN_CONFIDENCE = 0.30`.  
  * **Motivo:** O comportamento de compra na Northwind é transacional B2B e disperso em um catálogo de 77 produtos gourmet importados. As cestas são menores (média de 2 a 3 produtos).  
  * O produto individual mais frequente do Cluster 1 aparece em apenas 7,1% dos pedidos (34 de 478). Para que dois produtos aparecessem juntos em 5% das transações, seriam necessárias 24 ocorrências simultâneas do mesmo par, o que é raro em catálogos amplos e cestas enxutas.
  * Conforme validado em testes de sensibilidade, ao ajustar o suporte para a faixa de `1%` a `2%`, surgem regras de associação específicas para esses clusters (ex.: `{Chai} → {Flotemysost}`).

---

# 25. Validação do Processo e Métricas Obtidas

A validação foi confirmada em três níveis:

## 25.1 Validação dos Clusters
Consulta de verificação em `dm_vendas.cliente_cluster`:

```sql
SELECT cluster, COUNT(*) AS quantidade_clientes
FROM dm_vendas.cliente_cluster
GROUP BY cluster
ORDER BY cluster;
```

Resultado obtido:
* **Cluster 0:** 100 clientes
* **Cluster 1:** 39 clientes
* **Cluster 2:** 3 clientes
* **Cluster 3:** 47 clientes
* **Total:** 189 clientes classificados pelo K-Means.

---

## 25.2 Validação das Transações Reais
Consulta de verificação em `dm_vendas.vw_compras_por_cluster`:

```sql
SELECT cluster, COUNT(DISTINCT id_transacao) AS transacoes
FROM dm_vendas.vw_compras_por_cluster
GROUP BY cluster
ORDER BY cluster;
```

Resultado obtido:
* **Cluster 0:** 100 cestas
* **Cluster 1:** 478 cestas
* **Cluster 2:** 89 cestas
* **Cluster 3:** 263 cestas
* **Total:** 930 cestas/pedidos analisados.

---

## 25.3 Validação das Regras Gravadas
Consulta de conferência na tabela de destino:

```sql
SELECT cluster, COUNT(*) AS total_regras, 
       ROUND(AVG(confidence)::numeric, 2) AS conf_media,
       ROUND(AVG(lift)::numeric, 2) AS lift_medio
FROM dm_vendas.regras_associacao
GROUP BY cluster;
```

Resultado obtido:
* **3.804 regras gravadas** no Cluster 0, com confiança variando entre 0,30 e 1,00 e lift variando entre 1,00 e 5,00.

---

# 26. Cuidados Metodológicos e Lições Aprendidas

Durante o desenvolvimento da solução, três desafios metodológicos relevantes foram identificados e solucionados:

### 26.1 Granularidade da Tabela Fato vs. Granularidade da Cesta
A tabela fato opera na granularidade de **item de venda** (1 linha por produto). Utilizar o identificador da linha (`id_origem_registro`) como identificador da transação resulta em cestas de tamanho 1, o que inviabiliza o cálculo de coocorrência de múltiplos itens pelo Apriori. A solução correta foi reconstruir o ID da transação no nível do pedido (`id_venda` da Mercearia e `id_order` da Northwind) com prefixação de origem (`sistema_origem`), garantindo integridade e unicidade global no Data Mart.

### 26.2 Heterogeneidade de Fontes e Calibração de Suporte
Integrar dados de sistemas distintos (Mercearia B2C vs. Northwind B2B) exige atenção aos hiperparâmetros:
- Sistemas com cestas grandes e compras frequentes (supermercado) toleram suportes mais altos (`5%`).
- Sistemas com cestas enxutas e catálogo diversificado exigem suportes menores (`1%` a `2%`) para que padrões reais não sejam descartados.

### 26.3 Interpretação Conjunta de Suporte, Confiança e Lift
Uma regra com alta confiança pode ser espúria se o consequente for um item excessivamente popular. O uso do **Lift > 1,0** garantiu que apenas associações genuinamente informativas fossem mantidas.

---

# 27. Tecnologias Utilizadas

| Tecnologia | Função |
|---|---|
| PostgreSQL | Armazenamento e consulta dos dados |
| Data Warehouse | Integração dos dados |
| Data Mart `dm_vendas` | Organização dos dados para análise de vendas |
| Python | Execução dos algoritmos de mineração |
| Pandas | Manipulação dos dados |
| NumPy | Operações numéricas |
| SQLAlchemy | Conexão Python/PostgreSQL |
| Scikit-learn | K-Means, StandardScaler e Silhouette Score |
| MLxtend | Apriori e regras de associação |

---

# 28. Fluxo Completo da Solução

```text
                 FONTES DE DADOS
                 /             \
          Mercearia           Northwind
                 \             /
                  v           v
             DW ORGANIZACIONAL
             (dw_organizacional)
                     |
                     v
                DATA MART
               (dm_vendas)
                     |
                     v
        vw_cliente_clusterizacao
                     |
                     v
             Python (K-Means)
                     |
                     v
       Tabela dm_vendas.cliente_cluster
                     |
                     v
        vw_compras_por_cluster
    (id_transacao unificado por pedido)
                     |
                     v
              Python (Apriori)
              - Suporte >= 0.05
              - Confiança >= 0.30
              - Lift >= 1.00
                     |
                     v
         3.804 Regras de Associação
                     |
          +----------+----------+
          |                     |
          v                     v
regras_associacao_        dm_vendas.
  por_cluster.csv      regras_associacao
   (Arquivo CSV)         (PostgreSQL)
```

---

# 29. Conclusão

O projeto implementou com sucesso a integração entre **Data Warehouse Dimensional**, **Clusterização com K-Means** e **Mineração de Regras de Associação com Apriori** (técnica Ensemble não-supervisionada).

A solução superou o desafio de granularidade da modelagem dimensional (item de venda vs. cesta de compras), unificou duas fontes transacionais heterogêneas sem conflito de identificadores e produziu **3.804 regras de associação consistentes**, armazenadas tanto em arquivo analítico quanto na tabela dimensional no PostgreSQL (`dm_vendas.regras_associacao`).

Com isso, o Data Mart passa a disponibilizar não apenas relatórios históricos de vendas, mas também uma camada de inteligência prescritiva capaz de alimentar motores de recomendação e guiar decisões estratégicas de marketing e gestão de produtos.
