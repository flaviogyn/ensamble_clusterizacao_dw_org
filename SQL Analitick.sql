/*
 * Ensamble: clusterização de clientes com Regras de AssociaçãoTarefa
 * Combinar clusterização de clientes com Regras de Associação é uma estratégia extremamente poderosa para análises de CRM e marketing. 
 
 * A ideia central é simples: 
 * em vez de aplicar as regras de associação em toda a base de transações (o que pode gerar milhares de regras genéricas e pouco acionáveis), 
 * você "segmenta os clientes primeiro" e, 
 * em seguida, descobre padrões de compra "específicos para cada grupo".
 
 * Portanto, de posse do DW Organizacional ou Datamart construído para esse fim, 
 * povoar o BD e aplicar o conceito de ensemble (aprendizagem por conjuntos):
 *  1) Utilizar dados para clusterizar ou classificar os clientes
 * 	2) De posse das compras por por grupo/classe, aplicar as Regras de Descoberta de Associação entre produtos.
 * 
 * Obs: Para o trabalho pode-se utilizar as ferramentas das bibliotecas Python. 
 * Entregáveis: Código e relatório técnico do processo.
 */

-- Etapa A — Clusterização
-- Vamos pegar os clientes e encontrar grupos com características semelhantes.


-- dm_compras
select df.nome as fornecedor, 
	   0 qtd_compras,
	   0 valor_gasto,
	   0 produtos_diferente,
	   dp.produto,
	   dp.categoria,
	   fc.*
  from fato_compras fc
       inner join dim_fornecedor df on fc.id_fornecedor_dw = df.id_fornecedor_dw
	   inner join dim_produto dp on fc.id_produto_dw = dp.id_produto_dw;


-- Contagem de linhas e origem
SELECT
    COUNT(*) AS total_linhas,
    COUNT(id_origem_registro) AS linhas_com_origem,
    COUNT(DISTINCT id_origem_registro) AS vendas_distintas
FROM dm_vendas.fato_vendas;

-- vs 1
CREATE OR REPLACE VIEW dm_vendas.vw_cliente_clusterizacao AS
WITH vendas_cliente AS (
    SELECT
        fv.id_cliente_dw,
        COUNT(DISTINCT fv.id_origem_registro)
            AS frequencia_compras,
        SUM(fv.quantidade)
            AS quantidade_itens,
        SUM(fv.valor_liquido)
            AS valor_total,
        COUNT(DISTINCT fv.id_produto_dw)
            AS produtos_distintos,
        COUNT(DISTINCT dp.categoria)
            AS categorias_distintas,
        MAX(dt.data_completa)
            AS ultima_compra
    FROM dm_vendas.fato_vendas fv
    INNER JOIN dm_vendas.dim_produto dp
        ON dp.id_produto_dw = fv.id_produto_dw
    INNER JOIN dm_vendas.dim_tempo dt
        ON dt.id_tempo = fv.id_tempo
    GROUP BY
        fv.id_cliente_dw
),
data_referencia AS (
    SELECT
        MAX(data_completa) AS data_maxima
    FROM dm_vendas.dim_tempo
)
SELECT
    vc.id_cliente_dw,
    dc.id_pessoa,
    dc.nome AS nome_cliente,
    dc.tipo_cliente,
    dc.cidade,
    dc.regiao,
    dc.estado,
    dc.pais,
    vc.ultima_compra,
    (
        dr.data_maxima - vc.ultima_compra
    ) AS recencia_dias,
    vc.frequencia_compras,
    vc.quantidade_itens,
    ROUND(
        vc.valor_total,
        2
    ) AS valor_total,
    ROUND(
        vc.valor_total /
        NULLIF(vc.frequencia_compras, 0),
        2
    ) AS ticket_medio,
    vc.produtos_distintos,
    vc.categorias_distintas
FROM vendas_cliente vc
INNER JOIN dm_vendas.dim_cliente dc
    ON dc.id_cliente_dw = vc.id_cliente_dw
CROSS JOIN data_referencia dr;

-- vs 2
CREATE OR REPLACE VIEW dm_vendas.vw_cliente_clusterizacao AS
WITH vendas_cliente AS (
    SELECT
        fv.id_cliente_dw,
        COUNT(DISTINCT fv.id_origem_registro)
            AS frequencia_compras,
        SUM(fv.quantidade)
            AS quantidade_itens,
        SUM(fv.valor_liquido)
            AS valor_total,
        COUNT(DISTINCT fv.id_produto_dw)
            AS produtos_distintos,
        COUNT(DISTINCT dp.categoria)
            AS categorias_distintas,
        MAX(dt.data_completa)
            AS ultima_compra
    FROM dm_vendas.fato_vendas fv
    INNER JOIN dm_vendas.dim_produto dp
        ON dp.id_produto_dw = fv.id_produto_dw
    INNER JOIN dm_vendas.dim_tempo dt
        ON dt.id_tempo = fv.id_tempo
    GROUP BY
        fv.id_cliente_dw
),
data_referencia AS (
    SELECT
        MAX(dt.data_completa) AS data_maxima_venda
    FROM dm_vendas.fato_vendas fv
    INNER JOIN dm_vendas.dim_tempo dt
        ON dt.id_tempo = fv.id_tempo
)
SELECT
    vc.id_cliente_dw,
    dc.id_pessoa,
    dc.nome AS nome_cliente,
    dc.tipo_cliente,
    dc.cidade,
    dc.regiao,
    dc.estado,
    dc.pais,
    vc.ultima_compra,
    dr.data_maxima_venda - vc.ultima_compra
        AS recencia_dias,
    vc.frequencia_compras,
    vc.quantidade_itens,
    ROUND(vc.valor_total, 2)
        AS valor_total,
    ROUND(
        vc.valor_total /
        NULLIF(vc.frequencia_compras, 0),
        2
    ) AS ticket_medio,
    vc.produtos_distintos,
    vc.categorias_distintas
FROM vendas_cliente vc
INNER JOIN dm_vendas.dim_cliente dc
    ON dc.id_cliente_dw = vc.id_cliente_dw
CROSS JOIN data_referencia dr;

-- Dados Clustetizados
SELECT *
FROM dm_vendas.vw_cliente_clusterizacao
ORDER BY valor_total DESC;

-- Verificar se há problemas nos dados
SELECT
    COUNT(*) AS clientes,
    COUNT(*) FILTER (
        WHERE recencia_dias IS NULL
    ) AS recencia_nula,
    COUNT(*) FILTER (
        WHERE frequencia_compras IS NULL
    ) AS frequencia_nula,
    COUNT(*) FILTER (
        WHERE valor_total IS NULL
    ) AS valor_nulo,
    COUNT(*) FILTER (
        WHERE ticket_medio IS NULL
    ) AS ticket_nulo
FROM dm_vendas.vw_cliente_clusterizacao;

SELECT
    MIN(recencia_dias) AS recencia_min,
    MAX(recencia_dias) AS recencia_max,
    MIN(frequencia_compras) AS frequencia_min,
    MAX(frequencia_compras) AS frequencia_max,
    MIN(valor_total) AS valor_min,
    MAX(valor_total) AS valor_max,
    MIN(ticket_medio) AS ticket_min,
    MAX(ticket_medio) AS ticket_max
FROM dm_vendas.vw_cliente_clusterizacao;

-- tabela dos clusters
CREATE TABLE IF NOT EXISTS dm_vendas.cliente_cluster (
    id_cliente_dw BIGINT PRIMARY KEY,
    cluster INTEGER NOT NULL,
    data_processamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Validar se a tabela foi populada pelo k-meas python
SELECT
    COUNT(*) AS total_clientes
FROM dm_vendas.cliente_cluster;

-- Quantos clientes em cada cluster
SELECT
    cluster,
    COUNT(*) AS quantidade_clientes
FROM dm_vendas.cliente_cluster
GROUP BY cluster
ORDER BY cluster;

-- Ver os clientes
SELECT
    cc.id_cliente_dw,
    dc.nome AS nome_cliente,
    cc.cluster
FROM dm_vendas.cliente_cluster cc
INNER JOIN dm_vendas.dim_cliente dc
    ON dc.id_cliente_dw = cc.id_cliente_dw
ORDER BY
    cc.cluster,
    cc.id_cliente_dw;

-- Agora que existe a dm_vendas.cliente_cluster podemos associá-la às vendas.
SELECT
    cc.cluster,
    fv.id_cliente_dw,
    fv.id_origem_registro AS id_transacao,
    fv.id_produto_dw,
    dp.produto,
    dp.categoria,
    fv.quantidade,
    fv.valor_liquido
FROM dm_vendas.cliente_cluster cc
INNER JOIN dm_vendas.fato_vendas fv
    ON fv.id_cliente_dw = cc.id_cliente_dw
INNER JOIN dm_vendas.dim_produto dp
    ON dp.id_produto_dw = fv.id_produto_dw
ORDER BY
    cc.cluster,
    fv.id_cliente_dw,
    fv.id_origem_registro,
    dp.produto;

-- Criar a VIEW para o Apriori v1
CREATE OR REPLACE VIEW dm_vendas.vw_compras_por_cluster AS
SELECT
    cc.cluster,
    fv.id_cliente_dw,
    fv.id_origem_registro AS id_transacao,
    fv.id_produto_dw,
    dp.produto,
    dp.categoria,
    fv.quantidade,
    fv.valor_liquido
FROM dm_vendas.cliente_cluster cc
INNER JOIN dm_vendas.fato_vendas fv
    ON fv.id_cliente_dw = cc.id_cliente_dw
INNER JOIN dm_vendas.dim_produto dp
    ON dp.id_produto_dw = fv.id_produto_dw;

select *
  from dm_vendas.fato_vendas fv;

-- Criar a VIEW para o Apriori v2 (erro encontrado)
CREATE OR REPLACE VIEW dm_vendas.vw_compras_por_cluster AS
SELECT
    cc.cluster,
    fv.id_cliente_dw,
    COALESCE(
        'M_'  || dw.id_venda::TEXT,
        'NW_' || dw.id_order::TEXT
    )::VARCHAR(100) AS id_transacao,
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

-- Criar a VIEW para o Apriori v3
-- Recriar a view com o agrupador unificado de transação
CREATE OR REPLACE VIEW dm_vendas.vw_compras_por_cluster AS
SELECT
    cc.cluster,
    fv.id_cliente_dw,
    -- Identificador unificado por sistema de origem + número do pedido
    (fv.sistema_origem || '_' || COALESCE(dw.id_venda, dw.id_order)::TEXT)::VARCHAR(100) AS id_transacao,
    fv.id_produto_dw,
    dp.produto,
    dp.categoria,
    fv.quantidade,
    fv.valor_liquido
FROM dm_vendas.cliente_cluster cc
INNER JOIN dm_vendas.fato_vendas fv
    ON fv.id_cliente_dw = cc.id_cliente_dw
-- JOIN com o DW Integrado para acessar os pedidos originais (id_venda e id_order)
INNER JOIN dw_organizacional.fato_vendas dw
    ON dw.id_fato_venda_dw = fv.id_fato_venda_dw
INNER JOIN dm_vendas.dim_produto dp
    ON dp.id_produto_dw = fv.id_produto_dw;


SELECT *
FROM dm_vendas.vw_compras_por_cluster
ORDER BY
    cluster,
    id_cliente_dw,
    id_transacao;

-- Conferir amostra dos dados agrupados na view
SELECT 
    cluster,
    id_transacao,
    COUNT(*) AS total_itens_na_cesta,
    STRING_AGG(produto, ', ') AS produtos
FROM dm_vendas.vw_compras_por_cluster
GROUP BY cluster, id_transacao
ORDER BY cluster, id_transacao
LIMIT 10;


SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'dm_vendas'
  AND table_name = 'vw_compras_por_cluster'
ORDER BY ordinal_position;

-- 1
SELECT *
FROM dm_vendas.vw_cliente_clusterizacao
LIMIT 10;

-- 2
SELECT
    id_origem_registro,
    COUNT(*) AS quantidade_linhas
FROM dm_vendas.fato_vendas
GROUP BY id_origem_registro
ORDER BY quantidade_linhas DESC
LIMIT 20;

-- 3
SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT id_origem_registro) AS transacoes
FROM dm_vendas.fato_vendas;


SELECT
    cluster,
    COUNT(*) AS linhas,
    COUNT(DISTINCT id_transacao) AS transacoes,
    COUNT(DISTINCT id_produto_dw) AS produtos,
    COUNT(DISTINCT (id_transacao, id_produto_dw))
        AS pares_transacao_produto
FROM dm_vendas.vw_compras_por_cluster
GROUP BY cluster
ORDER BY cluster;

-- Suporte = Número de registros com X e Y / Número total de registros
-- verificar se é por venda os produtos
select produto, qtd, total_registros, ROUND((qtd::numeric / total_registros) * 100, 4) as suporte
from (select dp.produto, 
		   count(dp.produto) as qtd,
		   (select count(1) from fato_vendas fv) as total_registros
	  from fato_vendas fv
	  	   inner join dim_produto dp on fv.id_produto_dw = dp.id_produto_dw
	  group by dp.produto)
 order by 4 desc;

SELECT
    cluster,
    id_transacao,
    id_cliente_dw,
    COUNT(DISTINCT id_produto_dw) AS produtos_na_transacao
FROM dm_vendas.vw_compras_por_cluster
GROUP BY
    cluster,
    id_transacao,
    id_cliente_dw
ORDER BY produtos_na_transacao DESC
LIMIT 30;



-- dm_vendas

select dp.produto, dp.categoria, fv.* 
  from fato_vendas fv
  	   inner join dim_produto dp on fv.id_produto_dw = dp.id_produto_dw
  order by fv.id_fato_venda_dw, categoria;
  	   
select dp.categoria, count(fv.id_fato_venda_dw) qtq 
  from fato_vendas fv
  	   inner join dim_produto dp on fv.id_produto_dw = dp.id_produto_dw
  group by dp.categoria
  having count(fv.id_fato_venda_dw) > 1;

select fv.id_fato_venda_dw, count(fv.id_fato_venda_dw) qtq 
  from fato_vendas fv
  group by fv.id_fato_venda_dw
  having count(fv.id_fato_venda_dw) > 1;

select fv.id_fato_venda, count(fv.id_fato_venda) qtq 
  from dw_organizacional.fato_vendas fv
  group by fv.id_fato_venda_dw 
  having count(fv.id_fato_venda) > 1;

select fv.* 
  from fato_vendas fv
where fv.id_origem_registro = '10248';

select fv.* 
  from fato_vendas fv
where fv.sistema_origem = 'NORTHWIND'
  and fv.id_origem_registro = '10285:1';

select fv.* 
  from fato_vendas fv
where fv.sistema_origem = 'NORTHWIND'
  and id_origem_registro = '10248:11';

select fv.id_origem_registro, COUNT(fv.id_origem_registro) QTD 
  from fato_vendas fv
where fv.sistema_origem = 'NORTHWIND'
group by fv.id_origem_registro
having count(fv.id_origem_registro) = 1;


-- Suporte = Número de registros com X e Y / Número total de registros
-- verificar se é por venda os produtos
select produto, qtd, total_registros, ROUND((qtd::numeric / total_registros) * 100, 4) as suporte
from (select dp.produto, 
		   count(dp.produto) as qtd,
		   (select count(1) from fato_vendas fv) as total_registros
	  from fato_vendas fv
	  	   inner join dim_produto dp on fv.id_produto_dw = dp.id_produto_dw
	  group by dp.produto)
 order by 4 desc;


-- dw_organizacional
select *
from dw_organizacional.fato_vendas fv;

select *
from dw_organizacional.fato_vendas fv
where id_order = 10248;

-- mercearia
select id_venda, count(id_venda) qtd
from mercearia.vendas
group by id_venda
having count(id_venda) > 1;

-- northing
select *
from northwind.order_details od;

-- Suporte = Número de registros com X e Y / Número total de registros
select p.product_name, p.category_id, o.*
from northwind.orders o
     inner join northwind.order_details od on o.order_id = od.order_id
     inner join northwind.products p on od.product_id = p.product_id 
order by o.order_id;

-- 1. Ativar a extensão (necessário apenas uma vez por banco)
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- 2. Consulta usando crosstab
SELECT * FROM crosstab(
    -- Consulta principal que retorna: linha, categoria e valor
    $$ SELECT produto, mes, valor FROM vendas ORDER BY 1, 2 $$ ,
    -- Consulta secundária que define os cabeçalhos das colunas dinâmicas
    $$ SELECT DISTINCT mes FROM vendas ORDER BY mes $$
) AS ct (
    produto VARCHAR(50), 
    "Fevereiro" NUMERIC, 
    "Janeiro" NUMERIC
);


-- 1. Garanta que a extensão tablefunc esteja ativa
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- 2. Criação da função de pivot dinâmico
CREATE OR REPLACE FUNCTION northwind.gerar_matriz_produtos_dinamica()
RETURNS TEXT AS $$
DECLARE
    v_lista_colunas TEXT;
    v_query_completa TEXT;
BEGIN
    -- Busca todos os produtos únicos de forma ordenada para criar a definição das colunas
    -- Transforma os nomes dos produtos em: "Nome do Produto" VARCHAR(3)
    SELECT STRING_AGG(FORMAT('%I VARCHAR(3)', product_name), ', ' ORDER BY product_name)
    INTO v_lista_colunas
    FROM northwind.products;

    -- Monta a string do comando SQL usando o crosstab tradicional de 2 parâmetros
    v_query_completa := FORMAT('
        SELECT * FROM crosstab(
            -- Query 1: Retorna identificador (Linha), categoria (Coluna) e valor (Conteúdo)
            $S$ SELECT o.order_id, p.product_name, \'\'Sim\'\'::VARCHAR  
                FROM northwind.orders o
                INNER JOIN northwind.order_details od ON o.order_id = od.order_id
                INNER JOIN northwind.products p ON od.product_id = p.product_id 
                ORDER BY 1, 2 $S$,
            -- Query 2: Lista exata das colunas (Categorias) na mesma ordem da Query 1
            $S$ SELECT product_name FROM northwind.products ORDER BY product_name $S$
        ) AS matriz_pivo (
            order_id INT,
            %s
        );', v_lista_colunas);

    -- Retorna o comando SQL gerado para ser executado
    RETURN v_query_completa;
END;
$$ LANGUAGE plpgsql;

SELECT northwind.gerar_matriz_produtos_dinamica();


SELECT 
    o.order_id,
    STRING_AGG(p.product_name, ', ' ORDER BY p.product_name) AS produtos
FROM northwind.orders o
     INNER JOIN northwind.order_details od ON o.order_id = od.order_id
     INNER JOIN northwind.products p ON od.product_id = p.product_id 
GROUP BY o.order_id
ORDER BY o.order_id;



