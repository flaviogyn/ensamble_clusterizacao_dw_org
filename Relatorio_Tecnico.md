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

---

# 11. Etapa 2 — Compras por Cluster

Depois da classificação dos clientes, foi criada/utilizada a visão:

```text
dm_vendas.vw_compras_por_cluster
```

A visão apresenta a seguinte estrutura:

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

Cada registro representa um produto pertencente a uma determinada transação de um cliente que foi associado a um cluster.

Exemplo conceitual:

```text
cluster | id_cliente_dw | id_transacao | produto
--------|---------------|--------------|---------
0       | 10            | 1001         | Arroz
0       | 10            | 1001         | Feijão
0       | 10            | 1001         | Óleo
0       | 15            | 1010         | Café
1       | 22            | 1050         | Leite
```

---

# 12. Importância do `id_transacao`

O campo:

```text
id_transacao
```

é fundamental para a descoberta de associação.

Ele representa a cesta de compra.

Por exemplo:

```text
Transação 1001

    Arroz
    Feijão
    Óleo
```

Essa transação será convertida pelo Python para:

```python
["Arroz", "Feijão", "Óleo"]
```

Outra transação:

```text
Transação 1002

    Café
    Açúcar
```

será representada como:

```python
["Café", "Açúcar"]
```

O conjunto de todas essas listas forma a base de transações utilizada pelo Apriori.

---

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

# 21. Exportação dos Resultados

As regras são exportadas para:

```text
regras_associacao_por_cluster.csv
```

O arquivo pode posteriormente ser utilizado para:

- análise exploratória;
- visualização;
- construção de dashboards;
- apresentação dos resultados;
- identificação de oportunidades comerciais.

---

# 22. Exemplo de Interpretação

Considere uma regra hipotética:

```text
Cluster: 0

Antecedente: Arroz
Consequente: Feijão

Support: 0.32
Confidence: 0.78
Lift: 1.42
```

A interpretação é:

- 32% das transações do Cluster 0 possuem Arroz e Feijão;
- quando Arroz aparece, Feijão aparece em 78% dessas transações;
- o Lift de 1,42 indica uma associação positiva entre os produtos.

Essa regra pode indicar uma oportunidade para ações como:

- venda combinada;
- promoção conjunta;
- recomendação de produtos;
- organização de produtos próximos no ponto de venda;
- criação de kits.

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

# 24. Exemplo de Resultado Final

O resultado poderá assumir uma estrutura como:

| Cluster | Antecedente | Consequente | Suporte | Confiança | Lift |
|---:|---|---|---:|---:|---:|
| 0 | Arroz | Feijão | 0,32 | 0,78 | 1,42 |
| 0 | Feijão | Arroz | 0,32 | 0,61 | 1,42 |
| 1 | Café | Açúcar | 0,27 | 0,72 | 1,65 |
| 1 | Leite | Café | 0,18 | 0,64 | 1,38 |
| 2 | Arroz, Feijão | Óleo | 0,15 | 0,52 | 1,73 |

**Observação:** os valores acima são meramente ilustrativos. Os valores reais devem ser obtidos pela execução do código sobre os dados do Data Mart.

---

# 25. Validação do Processo

O processo deve ser validado em três níveis.

## 25.1 Validação dos clusters

Verificar a quantidade de clientes por cluster:

```sql
SELECT
    cluster,
    COUNT(*) AS quantidade_clientes
FROM dm_vendas.cliente_cluster
GROUP BY cluster
ORDER BY cluster;
```

O resultado deve demonstrar que os clientes foram distribuídos entre os grupos selecionados pelo K-Means.

---

## 25.2 Validação das transações

Verificar as transações por cluster:

```sql
SELECT
    cluster,
    COUNT(DISTINCT id_transacao) AS transacoes
FROM dm_vendas.vw_compras_por_cluster
GROUP BY cluster
ORDER BY cluster;
```

Essa consulta confirma que as cestas utilizadas pelo Apriori estão associadas aos respectivos clusters.

---

## 25.3 Validação das regras

No Python, verificar:

- quantidade de conjuntos frequentes;
- quantidade de regras;
- suporte;
- confiança;
- lift.

Também é importante verificar se os produtos presentes nas regras realmente pertencem às transações dos respectivos clusters.

---

# 26. Cuidados Metodológicos

Alguns cuidados são importantes para garantir a qualidade da análise.

### 26.1 Não utilizar o identificador da linha do fato como cesta

O campo `id_fato_venda_dw` identifica a linha da fato de vendas e não deve ser utilizado como identificador da cesta quando várias linhas pertencem à mesma transação.

Para o Apriori deve ser utilizado:

```text
id_transacao
```

presente na `vw_compras_por_cluster`.

### 26.2 Ajustar o suporte conforme o volume

Um suporte de 5% pode ser adequado como ponto inicial, mas deve ser avaliado conforme o número de transações de cada cluster.

Clusters muito pequenos podem gerar poucas regras.

### 26.3 Avaliar regras com diferentes métricas

Uma regra não deve ser considerada relevante somente por possuir alta confiança.

O ideal é avaliar conjuntamente:

```text
Support
Confidence
Lift
```

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

O fluxo final desenvolvido é:

```text
                 FONTES DE DADOS
                 /             \
                /               \
          Mercearia           Northwind
                \               /
                 \             /
                  v           v
             DW ORGANIZACIONAL
                    |
                    v
               dm_vendas
                    |
                    v
       vw_cliente_clusterizacao
                    |
                    v
                  Python
                    |
             StandardScaler
                    |
                    v
                 K-Means
                    |
                    v
          cliente_cluster
                    |
                    v
       vw_compras_por_cluster
                    |
                    v
                  Python
                    |
          Separação por Cluster
                    |
                    v
          TransactionEncoder
                    |
                    v
                 Apriori
                    |
                    v
        Regras de Associação
                    |
          +---------+---------+
          |         |         |
       Support  Confidence   Lift
          |         |         |
          +---------+---------+
                    |
                    v
    regras_associacao_por_cluster.csv
```

---

# 29. Conclusão

O processo desenvolvido combina duas técnicas de mineração de dados de maneira sequencial.

Inicialmente, o **K-Means** é utilizado para identificar grupos de clientes com comportamentos semelhantes de compra. As características utilizadas representam aspectos como recência, frequência, valor financeiro e diversidade de produtos.

Após a definição dos clusters, os clientes são associados às suas respectivas transações. Essas transações são então utilizadas como cestas de compra para aplicação do algoritmo **Apriori**.

A etapa de Regras de Associação permite identificar quais produtos aparecem conjuntamente com maior frequência dentro de cada grupo de clientes.

O resultado é uma análise mais direcionada:

```text
Comportamento dos clientes
          ↓
Segmentação
          ↓
Comportamento de compra por segmento
          ↓
Associações entre produtos
```

Assim, a solução atende ao objetivo do trabalho de utilizar os dados para **clusterizar/classificar clientes** e, a partir dos grupos obtidos, aplicar **Regras de Descoberta de Associação entre produtos**.

A abordagem também demonstra a utilização prática do Data Warehouse e do Data Mart como base para técnicas de Data Mining, preservando a separação entre a camada de armazenamento/integração dos dados e a camada analítica executada em Python.
