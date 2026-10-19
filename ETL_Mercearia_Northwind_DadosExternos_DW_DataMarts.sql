-- ============================================================
-- ETL - FONTES -> DW ORGANIZACIONAL -> DATA MARTS
-- PostgreSQL
--
-- Fontes:
--   mercearia.*
--   northwind.*
--   fontes_externas.dados_externos
--
-- IMPORTANTE SOBRE CHAVES:
--   id_* = chave natural/original da fonte, preservada no campo integrado.
--   *_dw = chave substituta gerada pelo DW.
--   sistema_origem identifica a origem e evita ambiguidade entre IDs iguais.
--
-- IMPORTANTE:
--   Execute primeiro o DDL:
--   DW_Organizacional_3_Data_Marts.sql
--
-- O processo abaixo é deliberadamente escrito como ETL SQL
-- (INSERT ... SELECT), com CTEs e tabelas de controle simples.
-- ============================================================

-- ============================================================
-- MODELO DE CHAVES INTEGRADAS (ATUALIZADO)
--   dim_cliente.id_pessoa      VARCHAR(50) + origem_principal
--   dim_produto.id_produto     VARCHAR(50) + origem_principal
--   dim_fornecedor.id_pessoa   VARCHAR(50) + origem_principal
--
-- As chaves de sistemas diferentes são consolidadas no mesmo
-- atributo. A origem identifica o sistema de procedência.
-- ============================================================

BEGIN;

-- ============================================================
-- 0. FONTES / METADADOS
-- ============================================================

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'MERCEARIA', 'Pessoas', 'TRANSACIONAL', 'Cadastro de pessoas/clientes'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='MERCEARIA' AND tabela_origem='Pessoas'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'MERCEARIA', 'Produtos', 'TRANSACIONAL', 'Cadastro de produtos'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='MERCEARIA' AND tabela_origem='Produtos'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'MERCEARIA', 'Vendas/Itens_Vendas', 'TRANSACIONAL', 'Transações de vendas'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='MERCEARIA' AND tabela_origem='Vendas/Itens_Vendas'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'MERCEARIA', 'Compras/Itens_compras', 'TRANSACIONAL', 'Transações de compras'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='MERCEARIA' AND tabela_origem='Compras/Itens_compras'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'NORTHWIND', 'customers', 'TRANSACIONAL', 'Cadastro de clientes'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='NORTHWIND' AND tabela_origem='customers'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'NORTHWIND', 'products', 'TRANSACIONAL', 'Cadastro de produtos'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='NORTHWIND' AND tabela_origem='products'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'NORTHWIND', 'orders/order_details', 'TRANSACIONAL', 'Pedidos e itens vendidos'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='NORTHWIND' AND tabela_origem='orders/order_details'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'NORTHWIND', 'suppliers', 'TRANSACIONAL', 'Cadastro de fornecedores'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='NORTHWIND' AND tabela_origem='suppliers'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'NORTHWIND', 'employees', 'TRANSACIONAL', 'Cadastro de vendedores'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='NORTHWIND' AND tabela_origem='employees'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'NORTHWIND', 'shippers', 'TRANSACIONAL', 'Cadastro de transportadoras'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='NORTHWIND' AND tabela_origem='shippers'
);

INSERT INTO dw_organizacional.dim_fonte_dado
    (sistema_origem, tabela_origem, tipo_fonte, descricao)
SELECT 'FONTES_EXTERNAS', 'dados_externos', 'EXTERNA', 'Indicadores externos sintéticos'
WHERE NOT EXISTS (
    SELECT 1 FROM dw_organizacional.dim_fonte_dado
    WHERE sistema_origem='FONTES_EXTERNAS' AND tabela_origem='dados_externos'
);

-- ============================================================
-- 1. DIMENSÃO TEMPO
-- ============================================================
-- A faixa é criada a partir das datas existentes nas fontes.
-- Caso a carga cresça futuramente, ampliar a faixa no ETL.

INSERT INTO dw_organizacional.dim_tempo (
    id_tempo, data_completa, dia, mes, nome_mes, trimestre,
    semestre, semana_ano, ano, dia_semana, nome_dia_semana,
    fim_de_semana, feriado
)
SELECT
    TO_CHAR(d,'YYYYMMDD')::INTEGER,
    d,
    EXTRACT(DAY FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    CASE EXTRACT(MONTH FROM d)::INTEGER
        WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro'
        WHEN 3 THEN 'Março' WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Maio' WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho' WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Setembro' WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
    END,
    EXTRACT(QUARTER FROM d)::INTEGER,
    CASE WHEN EXTRACT(MONTH FROM d)::INTEGER <= 6 THEN 1 ELSE 2 END,
    EXTRACT(WEEK FROM d)::INTEGER,
    EXTRACT(YEAR FROM d)::INTEGER,
    EXTRACT(ISODOW FROM d)::INTEGER,
    CASE EXTRACT(ISODOW FROM d)::INTEGER
        WHEN 1 THEN 'Segunda-feira' WHEN 2 THEN 'Terça-feira'
        WHEN 3 THEN 'Quarta-feira' WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira' WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END,
    EXTRACT(ISODOW FROM d)::INTEGER IN (6,7),
    FALSE
FROM (
    SELECT generate_series(
        LEAST(
            COALESCE((SELECT MIN(data_venda) FROM mercearia.vendas), CURRENT_DATE),
            COALESCE((SELECT MIN(order_date) FROM northwind.orders), CURRENT_DATE),
            COALESCE((SELECT MIN(data_referencia) FROM fontes_externas.dados_externos), CURRENT_DATE)
        ),
        GREATEST(
            COALESCE((SELECT MAX(data_faturamento) FROM mercearia.vendas), CURRENT_DATE),
            COALESCE((SELECT MAX(order_date) FROM northwind.orders), CURRENT_DATE),
            COALESCE((SELECT MAX(data_referencia) FROM fontes_externas.dados_externos), CURRENT_DATE)
        ),
        INTERVAL '1 day'
    )::DATE AS d
) x
ON CONFLICT (id_tempo) DO NOTHING;

-- ============================================================
-- 2. DADOS EXTERNOS
-- ============================================================

INSERT INTO dw_organizacional.dim_dados_externos (
    id_dado_externo, data_referencia, tipo_dado, indicador,
    descricao, valor, unidade, fonte, referencia_origem
)
SELECT
    e.id_dado_externo,
    e.data_referencia,
    e.tipo_dado,
    e.indicador,
    e.descricao,
    e.valor::NUMERIC(18,6),
    e.unidade,
    e.fonte,
    e.referencia_origem
FROM fontes_externas.dados_externos e
ON CONFLICT (id_dado_externo)
DO UPDATE SET
    data_referencia = EXCLUDED.data_referencia,
    tipo_dado = EXCLUDED.tipo_dado,
    indicador = EXCLUDED.indicador,
    descricao = EXCLUDED.descricao,
    valor = EXCLUDED.valor,
    unidade = EXCLUDED.unidade,
    fonte = EXCLUDED.fonte,
    referencia_origem = EXCLUDED.referencia_origem;

-- ============================================================
-- 3. DIMENSÃO CLIENTE
--
-- CONFLITO:
--   Mercearia.Pessoas  -> id_pessoa
--   Northwind.customers -> id_pessoa (customer_id convertido para VARCHAR)
--
-- DOMÍNIOS:
--   TIPO_PESSOA / contact information possuem estruturas
--   diferentes. O DW usa atributos comuns e mantém os dados
--   específicos quando disponíveis.
--
-- SEXO:
--   Nesta carga, a fonte Northwind não possui sexo.
--   Portanto NÃO é inventado sexo para Northwind.
--   Para Mercearia, padronizamos valores conhecidos para
--   M/F; valores não reconhecidos ficam NULL.
-- ============================================================

INSERT INTO dw_organizacional.dim_cliente (
    id_pessoa, origem_principal, tipo_cliente, nome, documento,
    sexo, renda, estado_civil, data_nascimento, profissao,
    endereco, complemento, cidade, regiao, estado, cep,
    pais, telefone, data_inicio, registro_atual
)
SELECT
    p.id_pessoa::VARCHAR(50),
    'MERCEARIA',
    CASE
        WHEN p.tipo_pessoa = 1 THEN 'FISICA'
        WHEN p.tipo_pessoa = 2 THEN 'JURIDICA'
        ELSE 'NAO_INFORMADO'
    END,
    p.nome,
    p.cpf_cnpj,
    CASE
        WHEN UPPER(TRIM(p.sexo)) IN ('M','1','MASCULINO') THEN 'M'
        WHEN UPPER(TRIM(p.sexo)) IN ('F','0','FEMININO') THEN 'F'
        ELSE NULL
    END,
    p.renda::NUMERIC(18,2),
    p.estado_civil,
    p.data_nascimento,
    pr.nome_profissao,
    l.logradouro,
    e.complemento,
    c.nome_cidade,
    b.regiaocidade,
    uf.nome_estado,
    l.cep::VARCHAR,
    'Brasil',
    CASE
        WHEN t.ddd IS NOT NULL
            THEN '(' || t.ddd::VARCHAR || ') ' || t.telefone
        ELSE t.telefone
    END,
    CURRENT_DATE,
    TRUE
FROM mercearia.pessoas p

LEFT JOIN mercearia.profissoes pr
    ON pr.id_profissao = p.id_profissao

LEFT JOIN LATERAL (
    SELECT e.*
    FROM mercearia.enderecos e
    WHERE e.id_pessoa = p.id_pessoa
    ORDER BY e.preferencial DESC, e.id_endereco
    LIMIT 1
) e ON TRUE

LEFT JOIN mercearia.logradouros l
    ON l.id_logradouro = e.id_logradouro

LEFT JOIN mercearia.bairros b
    ON b.id_bairro = l.id_bairro

LEFT JOIN mercearia.cidades c
    ON c.id_cidade = b.id_cidade

LEFT JOIN mercearia.uf uf
    ON uf.id_uf = c.id_uf

LEFT JOIN LATERAL (
    SELECT t.*
    FROM mercearia.telefones t
    WHERE t.id_pessoa = p.id_pessoa
      AND t.status = 'A'
    ORDER BY t.preferencial DESC, t.id_telefone
    LIMIT 1
) t ON TRUE

WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_cliente d
    WHERE d.id_pessoa = p.id_pessoa::VARCHAR
      AND d.origem_principal = 'MERCEARIA'
      AND d.registro_atual = TRUE
);

INSERT INTO dw_organizacional.dim_cliente (
    id_pessoa, origem_principal, tipo_cliente, nome, empresa,
    contato, cargo_contato, endereco, cidade, regiao, cep, pais,
    telefone, data_inicio, registro_atual
)
SELECT
    c.customer_id::VARCHAR,
    'NORTHWIND',
    'JURIDICA',
    COALESCE(c.contact_name, c.company_name),
    c.company_name,
    c.contact_name,
    c.contact_title,
    c.address,
    c.city,
    c.region,
    c.postal_code,
    c.country,
    c.phone,
    CURRENT_DATE,
    TRUE
FROM northwind.customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_cliente d
    WHERE d.id_pessoa = c.customer_id::VARCHAR
      AND d.origem_principal = 'NORTHWIND'
      AND d.registro_atual = TRUE
);

-- ============================================================
-- 4. DIMENSÃO FORNECEDOR
-- ============================================================

-- Mercearia: Compras.ID_PESSOA referencia Pessoas.
-- Mantemos a chave id_pessoa e o sistema de origem.
INSERT INTO dw_organizacional.dim_fornecedor (
    id_pessoa, origem_principal, nome, cidade, estado, pais,
    data_inicio, registro_atual
)
SELECT DISTINCT
    p.id_pessoa,
    'MERCEARIA',
    p.nome,
    c.nome_cidade,
    uf.nome_estado,
    'Brasil',
    CURRENT_DATE,
    TRUE
FROM mercearia.compras cp
JOIN mercearia.pessoas p
    ON p.id_pessoa = cp.id_pessoa
LEFT JOIN LATERAL (
    SELECT e.id_logradouro
    FROM mercearia.enderecos e
    WHERE e.id_pessoa = p.id_pessoa
    ORDER BY e.preferencial DESC, e.id_endereco
    LIMIT 1
) e ON TRUE
LEFT JOIN mercearia.logradouros l
    ON l.id_logradouro = e.id_logradouro
LEFT JOIN mercearia.bairros b
    ON b.id_bairro = l.id_bairro
LEFT JOIN mercearia.cidades c
    ON c.id_cidade = b.id_cidade
LEFT JOIN mercearia.uf uf
    ON uf.id_uf = c.id_uf
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_fornecedor d
    WHERE d.id_pessoa = p.id_pessoa
      AND d.origem_principal = 'MERCEARIA'
);

INSERT INTO dw_organizacional.dim_fornecedor (
    id_pessoa, origem_principal, nome, contato, cargo_contato,
    endereco, cidade, regiao, cep, pais, telefone, fax, homepage,
    data_inicio, registro_atual
)
SELECT
    s.supplier_id::INTEGER,
    'NORTHWIND',
    s.company_name,
    s.contact_name,
    s.contact_title,
    s.address,
    s.city,
    s.region,
    s.postal_code,
    s.country,
    s.phone,
    s.fax,
    s.homepage,
    CURRENT_DATE,
    TRUE
FROM northwind.suppliers s
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_fornecedor d
    WHERE d.id_pessoa = s.supplier_id::INTEGER
      AND d.origem_principal = 'NORTHWIND'
);

-- ============================================================
-- 5. DIMENSÃO PRODUTO
--
-- CONFLITO DE IDS:
--   Mercearia produto 1 != Northwind produto 1.
--
-- A chave substituta é id_produto_dw.
-- A chave natural integrada é id_produto e a origem_principal identifica a fonte.
-- ============================================================

INSERT INTO dw_organizacional.dim_produto (
    id_produto, origem_principal, produto, categoria,
    id_categoria, valor_venda, data_inicio, registro_atual
)
SELECT
    p.id_produto,
    'MERCEARIA',
    p.produto,
    c.nome_categoria,
    p.id_categoria,
    p.valor_venda::NUMERIC(18,4),
    CURRENT_DATE,
    TRUE
FROM mercearia.produtos p
LEFT JOIN mercearia.categorias c
    ON c.id_categoria = p.id_categoria
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_produto d
    WHERE d.id_produto = p.id_produto
      AND d.origem_principal = 'MERCEARIA'
);

INSERT INTO dw_organizacional.dim_produto (
    id_produto, origem_principal, produto, categoria,
    id_category, id_supplier, fornecedor, preco_unitario,
    quantidade_por_unidade, unidades_estoque, unidades_em_pedido,
    nivel_reposicao, descontinuado, data_inicio, registro_atual
)
SELECT
    p.product_id::INTEGER,
    'NORTHWIND',
    p.product_name,
    c.category_name,
    p.category_id,
    p.supplier_id,
    s.company_name,
    p.unit_price::NUMERIC(18,4),
    p.quantity_per_unit,
    p.units_in_stock,
    p.units_on_order,
    p.reorder_level,
    (p.discontinued <> 0),
    CURRENT_DATE,
    TRUE
FROM northwind.products p
LEFT JOIN northwind.categories c
    ON c.category_id = p.category_id
LEFT JOIN northwind.suppliers s
    ON s.supplier_id = p.supplier_id
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_produto d
    WHERE d.id_produto = p.product_id::INTEGER
      AND d.origem_principal = 'NORTHWIND'
);

-- ============================================================
-- 6. DIMENSÃO VENDEDOR - NORTHWIND
-- ============================================================

INSERT INTO dw_organizacional.dim_vendedor (
    id_employee, nome, sobrenome, cargo, tratamento,
    data_nascimento, data_contratacao, endereco, cidade,
    regiao, cep, pais, telefone, ramal, data_inicio, registro_atual
)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.title,
    e.title_of_courtesy,
    e.birth_date,
    e.hire_date,
    e.address,
    e.city,
    e.region,
    e.postal_code,
    e.country,
    e.home_phone,
    e.extension,
    CURRENT_DATE,
    TRUE
FROM northwind.employees e
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_vendedor d
    WHERE d.id_employee = e.employee_id
      AND d.registro_atual = TRUE
);

-- ============================================================
-- 7. DIMENSÃO TRANSPORTADORA - NORTHWIND
-- ============================================================

INSERT INTO dw_organizacional.dim_transportadora (
    id_shipper, nome, telefone, data_inicio, registro_atual
)
SELECT
    s.shipper_id,
    s.company_name,
    s.phone,
    CURRENT_DATE,
    TRUE
FROM northwind.shippers s
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_transportadora d
    WHERE d.id_shipper = s.shipper_id
      AND d.registro_atual = TRUE
);

-- ============================================================
-- 8. DIMENSÃO LOCALIZAÇÃO
-- ============================================================

INSERT INTO dw_organizacional.dim_localizacao (
    id_uf, id_cidade, id_bairro, id_logradouro, id_endereco,
    nome_estado, sigla_estado, nome_cidade, nome_bairro,
    regiao_cidade, tipo_logradouro, logradouro, cep,
    complemento, pais, origem_principal
)
SELECT
    uf.id_uf,
    c.id_cidade,
    b.id_bairro,
    l.id_logradouro,
    e.id_endereco,
    uf.nome_estado,
    uf.sigla,
    c.nome_cidade,
    b.nome_bairro,
    b.regiaocidade,
    l.tipo::VARCHAR,
    l.logradouro,
    l.cep::VARCHAR,
    e.complemento,
    'Brasil',
    'MERCEARIA'
FROM mercearia.enderecos e
JOIN mercearia.logradouros l
    ON l.id_logradouro = e.id_logradouro
JOIN mercearia.bairros b
    ON b.id_bairro = l.id_bairro
JOIN mercearia.cidades c
    ON c.id_cidade = b.id_cidade
JOIN mercearia.uf uf
    ON uf.id_uf = c.id_uf
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_localizacao d
    WHERE d.id_endereco = e.id_endereco
      AND d.origem_principal = 'MERCEARIA'
);

INSERT INTO dw_organizacional.dim_localizacao (
    nome_cidade, regiao, cep, pais, origem_principal
)
SELECT DISTINCT
    o.ship_city,
    o.ship_region,
    o.ship_postal_code,
    o.ship_country,
    'NORTHWIND'
FROM northwind.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.dim_localizacao d
    WHERE d.origem_principal = 'NORTHWIND'
      AND d.nome_cidade IS NOT DISTINCT FROM o.ship_city
      AND d.regiao IS NOT DISTINCT FROM o.ship_region
      AND d.cep IS NOT DISTINCT FROM o.ship_postal_code
      AND d.pais IS NOT DISTINCT FROM o.ship_country
);

-- ============================================================
-- 9. FATO VENDAS - MERCEARIA
--
-- GRANULARIDADE:
--   1 linha = 1 registro de Itens_Vendas.
--
-- Não usamos UNIQUE(id_venda,id_produto), pois o modelo fonte
-- permite que o mesmo produto possa aparecer em mais de um
-- item. A chave do item é preservada em id_itemvenda.
-- ============================================================

INSERT INTO dw_organizacional.fato_vendas (
    id_itemvenda, id_venda,
    id_cliente_dw, id_produto_dw, id_localizacao_dw,
    id_tempo, id_fonte_dw,
    data_venda, tipo_venda,
    quantidade, valor_unitario, percentual_desconto,
    valor_bruto, valor_desconto, valor_liquido,
    id_origem_registro, sistema_origem
)
SELECT
    iv.id_itemvenda,
    v.id_venda,
    dc.id_cliente_dw,
    dp.id_produto_dw,
    dl.id_localizacao_dw,
    TO_CHAR(v.data_venda,'YYYYMMDD')::INTEGER,
    ff.id_fonte_dw,
    v.data_venda,
    v.tipo_venda,
    iv.quantidade::NUMERIC(18,4),
    iv.vlr_unitario::NUMERIC(18,4),
    0::NUMERIC(9,6),
    (iv.quantidade * iv.vlr_unitario)::NUMERIC(18,4),
    0::NUMERIC(18,4),
    (iv.quantidade * iv.vlr_unitario)::NUMERIC(18,4),
    iv.id_itemvenda::VARCHAR,
    'MERCEARIA'
FROM mercearia.itens_vendas iv
JOIN mercearia.vendas v
    ON v.id_venda = iv.id_venda
JOIN dw_organizacional.dim_cliente dc
    ON dc.id_pessoa = v.id_pessoa::VARCHAR
   AND dc.origem_principal = 'MERCEARIA'
   AND dc.registro_atual = TRUE
JOIN dw_organizacional.dim_produto dp
    ON dp.id_produto = iv.id_produto
    --ON dp.id_produto::INTEGER = od.product_id::INTEGER
   AND dp.origem_principal = 'MERCEARIA'
   AND dp.registro_atual = TRUE
LEFT JOIN mercearia.enderecos e
    ON e.id_pessoa = v.id_pessoa
   AND e.preferencial = B'1'
LEFT JOIN dw_organizacional.dim_localizacao dl
    ON dl.id_endereco = e.id_endereco
   AND dl.origem_principal = 'MERCEARIA'
LEFT JOIN dw_organizacional.dim_fonte_dado ff
    ON ff.sistema_origem='MERCEARIA'
   AND ff.tabela_origem='Vendas/Itens_Vendas'
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.fato_vendas f
    WHERE f.id_itemvenda = iv.id_itemvenda
      AND f.sistema_origem = 'MERCEARIA'
);

-- ============================================================
-- 10. FATO VENDAS - NORTHWIND
--
-- GRANULARIDADE:
--   1 linha = 1 order_details.
--
-- DESCONTO:
--   Northwind armazena desconto como fração (ex.: 0.10 = 10%).
--
-- PRECISÃO:
--   unit_price/discount/freight são convertidos explicitamente
--   para NUMERIC.
--
-- FRETE:
--   O frete pertence ao pedido, não à linha.
--   Portanto não é rateado artificialmente neste ETL.
--   Fica NULL na linha para não duplicar um valor aditivo.
-- ============================================================

INSERT INTO dw_organizacional.fato_vendas (
    id_order,
    id_cliente_dw, id_produto_dw, id_vendedor_dw,
    id_transportadora_dw, id_localizacao_dw,
    id_tempo, id_fonte_dw,
    data_venda,
    quantidade, valor_unitario, percentual_desconto,
    valor_bruto, valor_desconto, valor_liquido,
    frete, id_origem_registro, sistema_origem
)
SELECT
    o.order_id,
    dc.id_cliente_dw,
    dp.id_produto_dw,
    dv.id_vendedor_dw,
    dt.id_transportadora_dw,
    dl.id_localizacao_dw,
    TO_CHAR(o.order_date,'YYYYMMDD')::INTEGER,
    ff.id_fonte_dw,
    o.order_date,
    od.quantity::NUMERIC(18,4),
    od.unit_price::NUMERIC(18,4),
    COALESCE(od.discount,0)::NUMERIC(9,6),
    (od.quantity * od.unit_price)::NUMERIC(18,4),
    (od.quantity * od.unit_price * COALESCE(od.discount,0))::NUMERIC(18,4),
    (od.quantity * od.unit_price * (1-COALESCE(od.discount,0)))::NUMERIC(18,4),
    NULL,
    o.order_id::VARCHAR || ':' || od.product_id::VARCHAR,
    'NORTHWIND'
FROM northwind.orders o
JOIN northwind.order_details od
    ON od.order_id = o.order_id
JOIN dw_organizacional.dim_cliente dc
    ON dc.id_pessoa = o.customer_id::VARCHAR
   AND dc.origem_principal = 'NORTHWIND'
   AND dc.registro_atual = TRUE
JOIN dw_organizacional.dim_produto dp
    ON dp.id_produto::INTEGER = od.product_id::INTEGER
   AND dp.origem_principal = 'NORTHWIND'
   AND dp.registro_atual = TRUE
LEFT JOIN dw_organizacional.dim_vendedor dv
    ON dv.id_employee = o.employee_id
   AND dv.registro_atual = TRUE
LEFT JOIN dw_organizacional.dim_transportadora dt
    ON dt.id_shipper = o.ship_via
   AND dt.registro_atual = TRUE
LEFT JOIN dw_organizacional.dim_localizacao dl
    ON dl.origem_principal = 'NORTHWIND'
   AND dl.nome_cidade IS NOT DISTINCT FROM o.ship_city
   AND dl.regiao IS NOT DISTINCT FROM o.ship_region
   AND dl.cep IS NOT DISTINCT FROM o.ship_postal_code
   AND dl.pais IS NOT DISTINCT FROM o.ship_country
LEFT JOIN dw_organizacional.dim_fonte_dado ff
    ON ff.sistema_origem='NORTHWIND'
   AND ff.tabela_origem='orders/order_details'
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.fato_vendas f
    WHERE f.id_order = o.order_id
      AND f.id_origem_registro =
            o.order_id::VARCHAR || ':' || od.product_id::VARCHAR
      AND f.sistema_origem = 'NORTHWIND'
);

-- ============================================================
-- 11. FATO COMPRAS - MERCEARIA
-- ============================================================

INSERT INTO dw_organizacional.fato_compras (
    id_itemcompra, id_compra,
    id_fornecedor_dw, id_produto_dw,
    id_tempo, id_fonte_dw,
    data_pedido, data_entrada,
    quantidade, valor_unitario, valor_total,
    id_origem_registro, sistema_origem
)
SELECT
    ic.id_itemcompra,
    c.id_compra,
    df.id_fornecedor_dw,
    dp.id_produto_dw,
    TO_CHAR(c.data_pedido,'YYYYMMDD')::INTEGER,
    ff.id_fonte_dw,
    c.data_pedido,
    c.data_entrada,
    ic.quantidade::NUMERIC(18,4),
    ic.vlr_unitario::NUMERIC(18,4),
    (ic.quantidade * ic.vlr_unitario)::NUMERIC(18,4),
    ic.id_itemcompra::VARCHAR,
    'MERCEARIA'
FROM mercearia.itens_compras ic
JOIN mercearia.compras c
    ON c.id_compra = ic.id_compra
JOIN dw_organizacional.dim_fornecedor df
    ON df.id_pessoa = c.id_pessoa
   AND df.origem_principal = 'MERCEARIA'
   AND df.registro_atual = TRUE
JOIN dw_organizacional.dim_produto dp
    ON dp.id_produto = ic.id_produto::INTEGER
   AND dp.origem_principal = 'MERCEARIA'
   AND dp.registro_atual = TRUE
LEFT JOIN dw_organizacional.dim_fonte_dado ff
    ON ff.sistema_origem='MERCEARIA'
   AND ff.tabela_origem='Compras/Itens_compras'
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.fato_compras f
    WHERE f.id_itemcompra = ic.id_itemcompra
      AND f.sistema_origem = 'MERCEARIA'
);

-- ============================================================
-- 12. FATO ESTOQUE - NORTHWIND
-- ============================================================
-- A origem fornece estoque atual, portanto cada carga representa
-- um snapshot. O id_origem_registro usa produto + data da carga
-- para manter a rastreabilidade.

INSERT INTO dw_organizacional.fato_estoque (
    id_produto_dw, id_tempo, id_fonte_dw,
    quantidade_estoque, quantidade_em_pedido, nivel_reposicao,
    valor_estoque, sistema_origem, id_origem_registro
)
SELECT
    dp.id_produto_dw,
    TO_CHAR(CURRENT_DATE,'YYYYMMDD')::INTEGER,
    ff.id_fonte_dw,
    p.units_in_stock::NUMERIC(18,4),
    p.units_on_order::NUMERIC(18,4),
    p.reorder_level::NUMERIC(18,4),
    (p.units_in_stock * p.unit_price)::NUMERIC(18,4),
    'NORTHWIND',
    p.product_id::VARCHAR || ':' || CURRENT_DATE::VARCHAR
FROM northwind.products p
JOIN dw_organizacional.dim_produto dp
    ON dp.id_produto = p.product_id::INTEGER
   AND dp.origem_principal = 'NORTHWIND'
   AND dp.registro_atual = TRUE
LEFT JOIN dw_organizacional.dim_fonte_dado ff
    ON ff.sistema_origem='NORTHWIND'
   AND ff.tabela_origem='products'
WHERE NOT EXISTS (
    SELECT 1
    FROM dw_organizacional.fato_estoque f
    WHERE f.id_origem_registro =
          p.product_id::VARCHAR || ':' || CURRENT_DATE::VARCHAR
      AND f.sistema_origem = 'NORTHWIND'
);

COMMIT;

-- ============================================================
-- 13. DATA MART 1 - VENDAS
-- ============================================================

INSERT INTO dm_vendas.dim_tempo
SELECT * FROM dw_organizacional.dim_tempo
ON CONFLICT (id_tempo) DO NOTHING;

INSERT INTO dm_vendas.dim_cliente (
    id_cliente_dw, id_pessoa, origem_principal, nome, empresa,
    cidade, regiao, estado, pais, tipo_cliente
)
SELECT
    id_cliente_dw, id_pessoa, origem_principal, nome, empresa,
    cidade, regiao, estado, pais, tipo_cliente
FROM dw_organizacional.dim_cliente
ON CONFLICT (id_cliente_dw) DO NOTHING;

INSERT INTO dm_vendas.dim_produto (
    id_produto_dw, id_produto, origem_principal, produto, categoria
)
SELECT id_produto_dw, id_produto, origem_principal, produto, categoria
FROM dw_organizacional.dim_produto
ON CONFLICT (id_produto_dw) DO NOTHING;

INSERT INTO dm_vendas.dim_vendedor (
    id_vendedor_dw, id_employee, nome, sobrenome, cargo
)
SELECT id_vendedor_dw, id_employee, nome, sobrenome, cargo
FROM dw_organizacional.dim_vendedor
ON CONFLICT (id_vendedor_dw) DO NOTHING;

INSERT INTO dm_vendas.dim_localizacao (
    id_localizacao_dw, cidade, estado, sigla_estado, pais, regiao
)
SELECT id_localizacao_dw, nome_cidade, nome_estado, sigla_estado, pais, regiao
FROM dw_organizacional.dim_localizacao
ON CONFLICT (id_localizacao_dw) DO NOTHING;

INSERT INTO dm_vendas.dim_dados_externos (
    id_dados_externos_dw, id_dado_externo, indicador,
    tipo_dado, valor, unidade, data_referencia
)
SELECT
    id_dados_externos_dw, id_dado_externo, indicador,
    tipo_dado, valor, unidade, data_referencia
FROM dw_organizacional.dim_dados_externos
ON CONFLICT (id_dados_externos_dw) DO NOTHING;

INSERT INTO dm_vendas.fato_vendas (
    id_fato_venda_dw, id_tempo, id_cliente_dw, id_produto_dw,
    id_vendedor_dw, id_localizacao_dw, quantidade, valor_unitario,
    valor_bruto, valor_desconto, valor_liquido, frete,
    id_origem_registro, sistema_origem
)
SELECT
    id_fato_venda_dw, id_tempo, id_cliente_dw, id_produto_dw,
    id_vendedor_dw, id_localizacao_dw, quantidade, valor_unitario,
    valor_bruto, valor_desconto, valor_liquido, frete,
    id_origem_registro, sistema_origem
FROM dw_organizacional.fato_vendas
ON CONFLICT (id_fato_venda_dw) DO NOTHING;

-- ============================================================
-- 14. DATA MART 2 - COMPRAS
-- ============================================================

INSERT INTO dm_compras.dim_tempo
SELECT * FROM dw_organizacional.dim_tempo
ON CONFLICT (id_tempo) DO NOTHING;

INSERT INTO dm_compras.dim_fornecedor (
    id_fornecedor_dw, id_pessoa, origem_principal, nome,
    cidade, estado, pais
)
SELECT id_fornecedor_dw, id_pessoa, origem_principal, nome,
       cidade, estado, pais
FROM dw_organizacional.dim_fornecedor
ON CONFLICT (id_fornecedor_dw) DO NOTHING;

INSERT INTO dm_compras.dim_produto (
    id_produto_dw, id_produto, origem_principal, produto, categoria
)
SELECT id_produto_dw, id_produto, origem_principal, produto, categoria
FROM dw_organizacional.dim_produto
ON CONFLICT (id_produto_dw) DO NOTHING;

INSERT INTO dm_compras.fato_compras (
    id_fato_compra_dw, id_tempo, id_fornecedor_dw, id_produto_dw,
    data_pedido, data_entrada, quantidade, valor_unitario,
    valor_total, id_origem_registro, sistema_origem
)
SELECT
    id_fato_compra_dw, id_tempo, id_fornecedor_dw, id_produto_dw,
    data_pedido, data_entrada, quantidade, valor_unitario,
    valor_total, id_origem_registro, sistema_origem
FROM dw_organizacional.fato_compras
ON CONFLICT (id_fato_compra_dw) DO NOTHING;

-- ============================================================
-- 15. DATA MART 3 - ESTOQUE
-- ============================================================

INSERT INTO dm_estoque.dim_tempo
SELECT * FROM dw_organizacional.dim_tempo
ON CONFLICT (id_tempo) DO NOTHING;

INSERT INTO dm_estoque.dim_produto (
    id_produto_dw, id_produto, origem_principal, produto, categoria,
    fornecedor, unidades_estoque, unidades_em_pedido,
    nivel_reposicao, descontinuado
)
SELECT
    id_produto_dw, id_produto, origem_principal, produto, categoria,
    fornecedor, unidades_estoque, unidades_em_pedido,
    nivel_reposicao, descontinuado
FROM dw_organizacional.dim_produto
ON CONFLICT (id_produto_dw) DO NOTHING;

INSERT INTO dm_estoque.dim_fonte_dado (
    id_fonte_dw, sistema_origem, tabela_origem, tipo_fonte
)
SELECT id_fonte_dw, sistema_origem, tabela_origem, tipo_fonte
FROM dw_organizacional.dim_fonte_dado
ON CONFLICT (id_fonte_dw) DO NOTHING;

INSERT INTO dm_estoque.fato_estoque (
    id_fato_estoque_dw, id_produto_dw, id_tempo, id_fonte_dw,
    quantidade_estoque, quantidade_em_pedido, nivel_reposicao,
    valor_estoque, id_origem_registro, sistema_origem
)
SELECT
    id_fato_estoque_dw, id_produto_dw, id_tempo, id_fonte_dw,
    quantidade_estoque, quantidade_em_pedido, nivel_reposicao,
    valor_estoque, id_origem_registro, sistema_origem
FROM dw_organizacional.fato_estoque
ON CONFLICT (id_fato_estoque_dw) DO NOTHING;

-- ============================================================
-- 16. CONSULTAS DE VALIDAÇÃO DO ETL
-- ============================================================

-- Contagem por sistema no DW:
-- SELECT sistema_origem, COUNT(*)
-- FROM dw_organizacional.fato_vendas
-- GROUP BY sistema_origem;

-- Verificar colisão de IDs de produtos:
-- SELECT sistema_origem, id_produto, origem_principal, id_produto_dw, produto
-- FROM dw_organizacional.dim_produto
-- ORDER BY produto;

-- Verificar rastreabilidade:
-- SELECT id_origem_registro, sistema_origem
-- FROM dw_organizacional.fato_vendas
-- LIMIT 20;

-- Verificar qualidade:
-- SELECT COUNT(*) FROM dw_organizacional.dim_cliente WHERE nome IS NULL;
-- SELECT COUNT(*) FROM dw_organizacional.dim_produto WHERE produto IS NULL;
-- SELECT COUNT(*) FROM dw_organizacional.fato_vendas WHERE quantidade IS NULL;

--rollback;