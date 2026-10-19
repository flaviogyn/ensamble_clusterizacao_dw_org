# Clusterização de Clientes & Regras de Associação
### Data Warehouse Organizacional — Mercearia + Northwind
**Data Mart:** dm_vendas | **Técnicas:** K-Means + Apriori | **IFG - Outubro/2026**

---

## Slide 1: Contexto e Objetivos do Projeto
### Mineração de dados integrada sobre o Data Warehouse Organizacional

* **Integração de Bases Distintas:**
  * **Mercearia (B2C):** 100 clientes, compras recorrentes e cestas amplas.
  * **Northwind (B2B):** 89 clientes, pedidos corporativos e catálogo especializado.
  * **Total Unificado:** 189 clientes consolidados via Data Warehouse.
* **O Pipeline em 4 Etapas Centrais:**
  1. Clusterizar clientes pelo comportamento de compra (K-Means).
  2. Segmentar as transações conforme o grupo de clientes.
  3. Aplicar o algoritmo Apriori separadamente por cluster.
  4. Extrair regras de associação específicas e acionáveis para o negócio.
* **Diferencial Estratégico:**
  * O algoritmo Apriori não é aplicado na base inteira, mas **dentro de cada segmento**, gerando regras hiper-específicas por perfil.

---

## Slide 2: Arquitetura da Solução e Fluxo de Dados
### Da ingestão transacional à descoberta de 3.804 regras de negócio

* **Fluxo Ponta a Ponta:**
  * Ingestão dos bancos Mercearia e Northwind no DW `dw_organizacional`.
  * Criação do Data Mart `dm_vendas` com visão analítica `vw_cliente_clusterizacao`.
  * Treinamento do modelo K-Means (K=4) e persistência em `cliente_cluster`.
  * Geração da visão unificada de transações `vw_compras_por_cluster`.
  * Mineração com Apriori e geração de 3.804 regras de associação.
* **Destaque de Engenharia de Dados:**
  * Criação do `id_transacao` global composto: `sistema_origem + '_' + id_pedido` (ex: `MERCEARIA_51`, `NORTHWIND_10249`), garantindo unicidade na granularidade correta do pedido.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/fluxo_solucao_1791584645911.jpg`

---

## Slide 3: Preparação e Normalização das Variáveis
### Engenharia de atributos comportamentais para o K-Means

* **As 7 Variáveis de Entrada Analisadas:**
  * `recencia_dias`: Dias decorridos desde a última compra realizada.
  * `frequencia_compras`: Quantidade total de pedidos efetuados.
  * `quantidade_itens`: Soma dos itens adquiridos pelo cliente.
  * `valor_total`: Montante financeiro total transacionado (R$).
  * `ticket_medio`: Valor médio por transação comercial.
  * `produtos_distintos`: Variedade de SKUs comprados.
  * `categorias_distintas`: Amplitude de categorias consumidas.
* **Por que a Normalização é Crítica?**
  * O algoritmo K-Means baseia-se em **distância euclidiana**.
  * Sem normalização, variáveis monetárias (na casa dos milhares) anulariam o impacto de variáveis como frequência (na casa das dezenas).
  * O `StandardScaler` equaliza todas as variáveis (média 0, desvio-padrão 1).

---

## Slide 4: Algoritmo K-Means e Seleção do K Ótimo
### Maximização da coesão interna e separação externa dos grupos

* **Como o K-Means Opera:**
  * Definição do número K de agrupamentos a serem formados.
  * Inicialização e alocação iterativa de cada cliente ao centroide mais próximo.
  * Recálculo sucessivo dos centroides até a convergência das distâncias.
* **Otimização pelo Silhouette Score:**
  * Foram testados empiricamente valores de K variando de 2 a 7.
  * O **Silhouette Score** avalia simultaneamente a coesão interna (proximidade dentro do cluster) e a separação externa (distância entre clusters distintos).
  * **Resultado Ótimo:** `K = 4` proporcionou o melhor equilíbrio estrutural para a base.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/kmeans_processo_1791584792834.jpg`

---

## Slide 5: Perfil e Distribuição dos 4 Clusters
### 189 clientes segmentados em perfis B2C e B2B distintos

* **Cluster 0 — B2C Mercearia (100 clientes):**
  * 100 transações, 100 produtos no catálogo. Cestas grandes (~10 itens/cesta), alta rotatividade e compras de abastecimento doméstico.
* **Cluster 1 — B2B Frequente Northwind (39 clientes):**
  * 478 transações, 77 produtos. Clientes corporativos recorrentes com pedidos enxutos (2 a 3 itens).
* **Cluster 2 — B2B Clientes VIP Northwind (3 clientes):**
  * 89 transações, 74 produtos. Alto volume financeiro e comportamento exclusivo que os isola dos demais.
* **Cluster 3 — B2B Intermediário Northwind (47 clientes):**
  * 263 transações, 76 produtos. Volume e frequência moderados no segmento corporativo.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/distribuicao_clusters_1791584657112.jpg`

---

## Slide 6: Pipeline Apriori e Market Basket Analysis
### Mineração de padrões frequentes executada por segmento

* **Estruturação da Matriz de Transações:**
  * Matriz binária (One-Hot Encoded via `TransactionEncoder` do MLxtend).
  * Linhas representam as transações individuais e colunas representam os produtos do catálogo.
* **Hiperparâmetros Calibrados:**
  * `MIN_SUPPORT = 0.05` (5%): O conjunto de itens deve estar presente em ao menos 5% das cestas.
  * `MIN_CONFIDENCE = 0.30` (30%): Probabilidade mínima de acerto da regra.
  * `MIN_LIFT = 1.00`: Filtro obrigatório para reter apenas correlações positivas.
* **Resultado da Execução por Cluster:**
  * **Cluster 0 (B2C):** Gerou **3.804 regras de associação válidas**.
  * **Clusters 1, 2 e 3 (B2B):** Não atingiram suporte de 5% devido à dispersão do catálogo.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/apriori_pipeline_1791584792834.jpg`

---

## Slide 7: Entendendo as Métricas de Associação
### O tripé analítico: Suporte, Confiança e Lift

* **Suporte (Support):**
  * Mede a frequência relativa com que um conjunto de produtos aparece em todas as transações.
  * Exemplo: Suporte de 16% significa presença garantida em 16 de cada 100 cestas.
* **Confiança (Confidence):**
  * Mede a certeza da regra: dado que o cliente comprou o item A, qual a chance de levar o item B?
  * Exemplo: Confiança de 100% significa que sempre que o antecedente foi comprado, o consequente também foi.
* **Lift (Fator de Elevação):**
  * Mede a força da regra comparada a uma compra puramente aleatória.
  * **Lift = 5,00:** Significa que o produto B tem **5 vezes mais chance** de ser comprado junto com A do que ao acaso.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/metricas_associacao_1791584702889.jpg`

---

## Slide 8: Exemplo Prático de Regra Descoberta
### Análise detalhada de padrões de compra do Cluster 0 (Mercearia)

* **Regra de Alto Impacto Identificada:**
  * **Antecedentes:** `Achocolatado 400g` + `Água Sanitária 1L`
  * **Consequente:** `Água Mineral 1.5L`
  * **Métricas:** Suporte = 16% | Confiança = 100% | Lift = 5,00
* **Outras Fortes Associações Encontradas (Confiança 100% | Lift 5,0):**
  * `Açúcar 1kg` + `Desinfetante 1L` → `Creme Dental 90g`
  * `Água Mineral 1.5L` + `Escova Dental` → `Água Sanitária 1L`
  * `Amaciante 2L` + `Feijão Carioca 1kg` → `Condicionador 350ml`
  * `Arroz 5kg` + `Sabão em Pó 1kg` → `Shampoo 350ml`
* **Insight de Consumo:** Cestas de feira familiar combinando limpeza, higiene e alimentos básicos em uma única jornada de compra.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/market_basket_exemplo_1791584716160.jpg`

---

## Slide 9: Análise Comparativa B2C vs B2B
### Densidade de catálogo e calibração de suporte

* **Por que os Clusters B2B não geraram regras com Suporte de 5%?**
  * No Cluster 1 (Northwind), o produto mais vendido aparece em apenas 7,1% dos pedidos.
  * Para dois produtos co-ocorrerem em 5% das cestas corporativas, precisariam estar juntos em 24 pedidos específicos.
  * Com cestas enxutas (2 a 3 itens) e catálogo disperso, a dispersão estatística é natural.
* **Ajuste e Solução Técnica:**
  * Calibrando o `MIN_SUPPORT` para **1% a 2%**, surgem regras B2B claras (ex: Chai → Flotemysost).
  * Conclusão: Não faltam padrões no B2B; a densidade de catálogo exige limiares adaptativos.
* **Mídia do Slide:**
  * Inserir imagem: `imagens_apresentacao/comparativo_clusters_1791584819835.jpg`

---

## Slide 10: Aplicações de Negócio e Conclusões
### Da análise histórica à inteligência prescritiva

* **Aplicações Práticas Imediatas:**
  * **Promoções Cruzadas:** Desconto no produto de entrada alavancando a venda do produto de alto Lift.
  * **Layout de Gôndola & Merchandising:** Posicionamento de produtos complementares em corredores adjacentes.
  * **Recomendações Inteligentes no Checkout:** Algoritmo dinâmico sugerindo o consequente com base no cluster do usuário.
  * **Kits Promocionais:** Criação de combos comerciais baseados em regras com Lift ≥ 5.
* **Síntese dos Resultados:**
  * **189 Clientes** segmentados com rigor estatístico (K-Means).
  * **930 Cestas** analisadas e **3.804 Regras** catalogadas no PostgreSQL (`dm_vendas.regras_associacao`).
  * O Data Mart evoluiu de simples repositório histórico para um motor ativo de decisão estratégica.
