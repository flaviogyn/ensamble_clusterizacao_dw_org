-- ============================================================
-- DW ORGANIZACIONAL
-- Mercearia + Northwind + Dados Externos
-- PostgreSQL
--
-- Estratégia:
--   Fontes -> ETL -> DW Organizacional Integrado -> 3 Data Marts
--
-- Regra de rastreabilidade:
--   As chaves naturais das fontes são preservadas com prefixo id_
--   e identificam explicitamente a tabela de origem.
--   Exemplos: id_pessoa, id_produto, sempre acompanhados de origem_principal.
--
-- O DW Organizacional mantém os dados integrados e detalhados.
-- Os Data Marts são dimensionais (Star Schema).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS dw_organizacional;
CREATE SCHEMA IF NOT EXISTS dm_vendas;
CREATE SCHEMA IF NOT EXISTS dm_compras;
CREATE SCHEMA IF NOT EXISTS dm_estoque;

-- ============================================================
-- 1. DIMENSÕES DO DW ORGANIZACIONAL
-- ============================================================

-- ------------------------------------------------------------
-- DIMENSÃO TEMPO
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_tempo (
    id_tempo            INTEGER PRIMARY KEY,
    data_completa       DATE NOT NULL UNIQUE,
    dia                 INTEGER NOT NULL,
    mes                 INTEGER NOT NULL,
    nome_mes            VARCHAR(20) NOT NULL,
    trimestre            INTEGER NOT NULL,
    semestre             INTEGER NOT NULL,
    semana_ano           INTEGER NOT NULL,
    ano                  INTEGER NOT NULL,
    dia_semana           INTEGER NOT NULL,
    nome_dia_semana      VARCHAR(20) NOT NULL,
    fim_de_semana        BOOLEAN NOT NULL,
    feriado              BOOLEAN NOT NULL DEFAULT FALSE
);

-- ------------------------------------------------------------
-- DIMENSÃO CLIENTE / PESSOA
--
-- Uma mesma dimensão integra:
--   Mercearia.Pessoas      -> id_pessoa
--   Northwind.customers    -> id_pessoa (customer_id convertido para VARCHAR)
--
-- A chave natural integrada é id_pessoa e a origem_principal identifica a fonte.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_cliente (
    id_cliente_dw         BIGSERIAL PRIMARY KEY,

    id_pessoa              VARCHAR(50),

    origem_principal       VARCHAR(30) NOT NULL,
    tipo_cliente           VARCHAR(30),

    nome                   VARCHAR(255),
    documento              VARCHAR(255),
    sexo                   VARCHAR(50),
    renda                  NUMERIC(18,2),
    estado_civil           VARCHAR(100),
    data_nascimento        DATE,

    profissao              VARCHAR(100),

    empresa                VARCHAR(255),
    contato                VARCHAR(255),
    cargo_contato          VARCHAR(100),

    endereco               VARCHAR(255),
    complemento            VARCHAR(255),
    cidade                 VARCHAR(100),
    regiao                 VARCHAR(100),
    estado                 VARCHAR(100),
    cep                    VARCHAR(30),
    pais                   VARCHAR(100),
    telefone               VARCHAR(100),

    data_inicio            DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim               DATE,
    registro_atual         BOOLEAN NOT NULL DEFAULT TRUE,

    data_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_dim_cliente_origem
        CHECK (origem_principal IN ('MERCEARIA','NORTHWIND','INTEGRADO')),

    CONSTRAINT ck_dim_cliente_chave_origem
        CHECK (id_pessoa IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS ix_dim_cliente_id_pessoa
    ON dw_organizacional.dim_cliente (id_pessoa);

-- ------------------------------------------------------------
-- DIMENSÃO PRODUTO
--
-- Mercearia.Produtos -> id_produto
-- Northwind.products -> product_id convertido para id_produto
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_produto (
    id_produto_dw        BIGSERIAL PRIMARY KEY,

    id_produto             INTEGER,

    origem_principal       VARCHAR(30) NOT NULL,

    produto                VARCHAR(255) NOT NULL,
    categoria              VARCHAR(255),
    id_categoria           INTEGER,
    id_category            SMALLINT,

    fornecedor             VARCHAR(255),
    id_fornecedor          INTEGER,
    id_supplier            SMALLINT,

    valor_venda            NUMERIC(18,4),
    preco_unitario         NUMERIC(18,4),

    quantidade_por_unidade VARCHAR(100),
    unidades_estoque       INTEGER,
    unidades_em_pedido     INTEGER,
    nivel_reposicao        INTEGER,
    descontinuado          BOOLEAN,

    data_inicio            DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim               DATE,
    registro_atual         BOOLEAN NOT NULL DEFAULT TRUE,

    data_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_dim_produto_origem
        CHECK (origem_principal IN ('MERCEARIA','NORTHWIND','INTEGRADO')),

    CONSTRAINT ck_dim_produto_chave_origem
        CHECK (id_produto IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS ix_dim_produto_id_produto
    ON dw_organizacional.dim_produto (id_produto);

-- ------------------------------------------------------------
-- DIMENSÃO FORNECEDOR
--
-- Mercearia: Compras.ID_PESSOA -> id_pessoa
-- Northwind: suppliers.supplier_id -> id_pessoa
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_fornecedor (
    id_fornecedor_dw      BIGSERIAL PRIMARY KEY,

    id_pessoa              INTEGER,

    origem_principal       VARCHAR(30) NOT NULL,

    nome                   VARCHAR(255) NOT NULL,
    contato                VARCHAR(255),
    cargo_contato          VARCHAR(100),

    endereco               VARCHAR(255),
    cidade                 VARCHAR(100),
    regiao                 VARCHAR(100),
    estado                 VARCHAR(100),
    cep                    VARCHAR(30),
    pais                   VARCHAR(100),
    telefone               VARCHAR(100),
    fax                    VARCHAR(100),
    homepage               VARCHAR(255),

    data_inicio            DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim               DATE,
    registro_atual         BOOLEAN NOT NULL DEFAULT TRUE,

    data_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_dim_fornecedor_origem
        CHECK (origem_principal IN ('MERCEARIA','NORTHWIND','INTEGRADO'))
);

CREATE INDEX IF NOT EXISTS ix_dim_fornecedor_id_pessoa
    ON dw_organizacional.dim_fornecedor (id_pessoa);

-- ------------------------------------------------------------
-- DIMENSÃO VENDEDOR
-- Northwind.employees -> id_employee
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_vendedor (
    id_vendedor_dw       BIGSERIAL PRIMARY KEY,

    id_employee          SMALLINT NOT NULL,

    nome                 VARCHAR(100) NOT NULL,
    sobrenome            VARCHAR(100),
    cargo                VARCHAR(100),
    tratamento           VARCHAR(50),

    data_nascimento      DATE,
    data_contratacao     DATE,

    endereco             VARCHAR(255),
    cidade               VARCHAR(100),
    regiao               VARCHAR(100),
    cep                  VARCHAR(30),
    pais                 VARCHAR(100),

    telefone             VARCHAR(100),
    ramal                VARCHAR(30),

    data_inicio          DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim             DATE,
    registro_atual       BOOLEAN NOT NULL DEFAULT TRUE,

    data_carga           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_dim_vendedor_id_employee
    ON dw_organizacional.dim_vendedor (id_employee);

-- ------------------------------------------------------------
-- DIMENSÃO TRANSPORTADORA
-- Northwind.shippers -> id_shipper
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_transportadora (
    id_transportadora_dw BIGSERIAL PRIMARY KEY,

    id_shipper           SMALLINT NOT NULL,

    nome                 VARCHAR(255) NOT NULL,
    telefone             VARCHAR(100),

    data_inicio          DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim             DATE,
    registro_atual       BOOLEAN NOT NULL DEFAULT TRUE,

    data_carga           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- DIMENSÃO LOCALIZAÇÃO
-- Integra a hierarquia geográfica da Mercearia e o endereço
-- de entrega do Northwind.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_localizacao (
    id_localizacao_dw    BIGSERIAL PRIMARY KEY,

    id_uf                INTEGER,
    id_cidade            INTEGER,
    id_bairro            INTEGER,
    id_logradouro        INTEGER,
    id_endereco          INTEGER,

    nome_estado          VARCHAR(100),
    sigla_estado         VARCHAR(20),
    nome_cidade          VARCHAR(255),
    nome_bairro          VARCHAR(255),
    regiao_cidade        VARCHAR(255),
    tipo_logradouro      VARCHAR(100),
    logradouro           VARCHAR(255),
    cep                  VARCHAR(30),
    complemento          VARCHAR(255),

    pais                 VARCHAR(100),
    regiao               VARCHAR(100),

    origem_principal     VARCHAR(30) NOT NULL,

    CONSTRAINT ck_dim_localizacao_origem
        CHECK (origem_principal IN ('MERCEARIA','NORTHWIND','EXTERNO','INTEGRADO'))
);

-- ------------------------------------------------------------
-- DIMENSÃO FONTE
-- Metadados e auditoria da origem do dado.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_fonte_dado (
    id_fonte_dw          BIGSERIAL PRIMARY KEY,

    sistema_origem       VARCHAR(100) NOT NULL,
    tabela_origem        VARCHAR(100) NOT NULL,
    tipo_fonte            VARCHAR(50) NOT NULL,
    descricao             VARCHAR(255),

    data_carga            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- DIMENSÃO DADOS EXTERNOS
-- Preserva id_dado_externo criado anteriormente.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.dim_dados_externos (
    id_dados_externos_dw BIGSERIAL PRIMARY KEY,

    id_dado_externo      VARCHAR(100) NOT NULL UNIQUE,

    data_referencia      DATE NOT NULL,
    tipo_dado             VARCHAR(50) NOT NULL,
    indicador             VARCHAR(100) NOT NULL,
    descricao             VARCHAR(200),
    valor                 NUMERIC(18,6) NOT NULL,
    unidade               VARCHAR(50),
    fonte                 VARCHAR(100) NOT NULL,
    referencia_origem     VARCHAR(200),

    data_carga            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. FATOS DO DW ORGANIZACIONAL
-- ============================================================

-- ------------------------------------------------------------
-- FATO VENDAS
-- Granularidade:
--   1 linha = 1 item de venda/pedido na fonte.
--
-- Mercearia:
--   Vendas + Itens_Vendas
--
-- Northwind:
--   orders + order_details
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.fato_vendas (
    id_fato_venda_dw      BIGSERIAL PRIMARY KEY,

    id_itemvenda           INTEGER,
    id_venda               INTEGER,

    id_order               INTEGER,

    id_cliente_dw          BIGINT,
    id_produto_dw          BIGINT,
    id_vendedor_dw         BIGINT,
    id_transportadora_dw   BIGINT,
    id_localizacao_dw      BIGINT,
    id_tempo               INTEGER,
    id_fonte_dw            BIGINT,

    data_venda             DATE NOT NULL,

    tipo_venda             INTEGER,

    quantidade             NUMERIC(18,4) NOT NULL,
    valor_unitario         NUMERIC(18,4) NOT NULL,
    percentual_desconto    NUMERIC(9,6) DEFAULT 0,

    valor_bruto            NUMERIC(18,4) NOT NULL,
    valor_desconto         NUMERIC(18,4) NOT NULL DEFAULT 0,
    valor_liquido          NUMERIC(18,4) NOT NULL,

    frete                  NUMERIC(18,4),

    id_origem_registro     VARCHAR(100),
    sistema_origem         VARCHAR(50) NOT NULL,

    data_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fv_tempo
        FOREIGN KEY (id_tempo)
        REFERENCES dw_organizacional.dim_tempo(id_tempo),

    CONSTRAINT fk_fv_cliente
        FOREIGN KEY (id_cliente_dw)
        REFERENCES dw_organizacional.dim_cliente(id_cliente_dw),

    CONSTRAINT fk_fv_produto
        FOREIGN KEY (id_produto_dw)
        REFERENCES dw_organizacional.dim_produto(id_produto_dw),

    CONSTRAINT fk_fv_vendedor
        FOREIGN KEY (id_vendedor_dw)
        REFERENCES dw_organizacional.dim_vendedor(id_vendedor_dw),

    CONSTRAINT fk_fv_transportadora
        FOREIGN KEY (id_transportadora_dw)
        REFERENCES dw_organizacional.dim_transportadora(id_transportadora_dw),

    CONSTRAINT fk_fv_localizacao
        FOREIGN KEY (id_localizacao_dw)
        REFERENCES dw_organizacional.dim_localizacao(id_localizacao_dw),

    CONSTRAINT fk_fv_fonte
        FOREIGN KEY (id_fonte_dw)
        REFERENCES dw_organizacional.dim_fonte_dado(id_fonte_dw)
);

CREATE INDEX IF NOT EXISTS ix_fato_vendas_tempo
    ON dw_organizacional.fato_vendas (id_tempo);

CREATE INDEX IF NOT EXISTS ix_fato_vendas_cliente
    ON dw_organizacional.fato_vendas (id_cliente_dw);

CREATE INDEX IF NOT EXISTS ix_fato_vendas_produto
    ON dw_organizacional.fato_vendas (id_produto_dw);

-- ------------------------------------------------------------
-- FATO COMPRAS
-- Granularidade:
--   1 linha = 1 item de compra.
--
-- Origem:
--   Mercearia.Compras + Itens_compras
--
-- Northwind não possui uma transação de compras equivalente
-- no DDL fornecido, portanto não serão inventados registros.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.fato_compras (
    id_fato_compra_dw     BIGSERIAL PRIMARY KEY,

    id_itemcompra         INTEGER,
    id_compra             INTEGER,

    id_fornecedor_dw      BIGINT,
    id_produto_dw         BIGINT,
    id_tempo              INTEGER,
    id_fonte_dw           BIGINT,

    data_pedido           DATE NOT NULL,
    data_entrada          DATE,

    quantidade             NUMERIC(18,4) NOT NULL,
    valor_unitario         NUMERIC(18,4) NOT NULL,
    valor_total            NUMERIC(18,4) NOT NULL,

    id_origem_registro     VARCHAR(100),
    sistema_origem         VARCHAR(50) NOT NULL,

    data_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fc_tempo
        FOREIGN KEY (id_tempo)
        REFERENCES dw_organizacional.dim_tempo(id_tempo),

    CONSTRAINT fk_fc_fornecedor
        FOREIGN KEY (id_fornecedor_dw)
        REFERENCES dw_organizacional.dim_fornecedor(id_fornecedor_dw),

    CONSTRAINT fk_fc_produto
        FOREIGN KEY (id_produto_dw)
        REFERENCES dw_organizacional.dim_produto(id_produto_dw),

    CONSTRAINT fk_fc_fonte
        FOREIGN KEY (id_fonte_dw)
        REFERENCES dw_organizacional.dim_fonte_dado(id_fonte_dw)
);

CREATE INDEX IF NOT EXISTS ix_fato_compras_tempo
    ON dw_organizacional.fato_compras (id_tempo);

CREATE INDEX IF NOT EXISTS ix_fato_compras_fornecedor
    ON dw_organizacional.fato_compras (id_fornecedor_dw);

CREATE INDEX IF NOT EXISTS ix_fato_compras_produto
    ON dw_organizacional.fato_compras (id_produto_dw);

-- ------------------------------------------------------------
-- FATO ESTOQUE
-- Granularidade:
--   1 linha = 1 produto por data de fotografia/snapshot.
--
-- Mercearia:
--   estoque pode ser derivado da movimentação de compras/vendas.
--
-- Northwind:
--   products possui units_in_stock, units_on_order e reorder_level.
--
-- O ETL deve carregar snapshots, preservando o histórico.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_organizacional.fato_estoque (
    id_fato_estoque_dw    BIGSERIAL PRIMARY KEY,

    id_produto_dw         BIGINT NOT NULL,
    id_tempo              INTEGER NOT NULL,
    id_fonte_dw           BIGINT,

    quantidade_estoque    NUMERIC(18,4),
    quantidade_em_pedido  NUMERIC(18,4),
    nivel_reposicao       NUMERIC(18,4),

    valor_estoque         NUMERIC(18,4),

    sistema_origem        VARCHAR(50) NOT NULL,
    id_origem_registro    VARCHAR(100),

    data_carga             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fe_produto
        FOREIGN KEY (id_produto_dw)
        REFERENCES dw_organizacional.dim_produto(id_produto_dw),

    CONSTRAINT fk_fe_tempo
        FOREIGN KEY (id_tempo)
        REFERENCES dw_organizacional.dim_tempo(id_tempo),

    CONSTRAINT fk_fe_fonte
        FOREIGN KEY (id_fonte_dw)
        REFERENCES dw_organizacional.dim_fonte_dado(id_fonte_dw)
);

CREATE INDEX IF NOT EXISTS ix_fato_estoque_produto
    ON dw_organizacional.fato_estoque (id_produto_dw);

CREATE INDEX IF NOT EXISTS ix_fato_estoque_tempo
    ON dw_organizacional.fato_estoque (id_tempo);

-- ============================================================
-- 3. DATA MART 1 - VENDAS
-- STAR SCHEMA
-- ============================================================

CREATE TABLE IF NOT EXISTS dm_vendas.dim_tempo (
    id_tempo INTEGER PRIMARY KEY,
    data_completa DATE NOT NULL,
    dia INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    nome_mes VARCHAR(20),
    trimestre INTEGER,
    semestre INTEGER,
    semana_ano INTEGER,
    ano INTEGER,
    dia_semana INTEGER,
    nome_dia_semana VARCHAR(20),
    fim_de_semana BOOLEAN,
    feriado BOOLEAN
);

CREATE TABLE IF NOT EXISTS dm_vendas.dim_cliente (
    id_cliente_dw BIGINT PRIMARY KEY,
    id_pessoa VARCHAR(50),
    origem_principal VARCHAR(30),
    nome VARCHAR(255),
    empresa VARCHAR(255),
    cidade VARCHAR(100),
    regiao VARCHAR(100),
    estado VARCHAR(100),
    pais VARCHAR(100),
    tipo_cliente VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS dm_vendas.dim_produto (
    id_produto_dw BIGINT PRIMARY KEY,
    id_produto INTEGER,
    origem_principal VARCHAR(30),
    produto VARCHAR(255),
    categoria VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS dm_vendas.dim_vendedor (
    id_vendedor_dw BIGINT PRIMARY KEY,
    id_employee SMALLINT,
    nome VARCHAR(100),
    sobrenome VARCHAR(100),
    cargo VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS dm_vendas.dim_localizacao (
    id_localizacao_dw BIGINT PRIMARY KEY,
    cidade VARCHAR(255),
    estado VARCHAR(100),
    sigla_estado VARCHAR(20),
    pais VARCHAR(100),
    regiao VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS dm_vendas.dim_dados_externos (
    id_dados_externos_dw BIGINT PRIMARY KEY,
    id_dado_externo VARCHAR(100),
    indicador VARCHAR(100),
    tipo_dado VARCHAR(50),
    valor NUMERIC(18,6),
    unidade VARCHAR(50),
    data_referencia DATE
);

CREATE TABLE IF NOT EXISTS dm_vendas.fato_vendas (
    id_fato_venda_dw BIGINT PRIMARY KEY,

    id_tempo INTEGER NOT NULL,
    id_cliente_dw BIGINT NOT NULL,
    id_produto_dw BIGINT NOT NULL,
    id_vendedor_dw BIGINT,
    id_localizacao_dw BIGINT,

    quantidade NUMERIC(18,4) NOT NULL,
    valor_unitario NUMERIC(18,4) NOT NULL,
    valor_bruto NUMERIC(18,4) NOT NULL,
    valor_desconto NUMERIC(18,4) NOT NULL,
    valor_liquido NUMERIC(18,4) NOT NULL,
    frete NUMERIC(18,4),

    id_origem_registro VARCHAR(100),
    sistema_origem VARCHAR(50)
);

-- ============================================================
-- 4. DATA MART 2 - COMPRAS
-- STAR SCHEMA
-- ============================================================

CREATE TABLE IF NOT EXISTS dm_compras.dim_tempo (
    id_tempo INTEGER PRIMARY KEY,
    data_completa DATE NOT NULL,
    dia INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    nome_mes VARCHAR(20),
    trimestre INTEGER,
    semestre INTEGER,
    semana_ano INTEGER,
    ano INTEGER,
    dia_semana INTEGER,
    nome_dia_semana VARCHAR(20),
    fim_de_semana BOOLEAN,
    feriado BOOLEAN
);

CREATE TABLE IF NOT EXISTS dm_compras.dim_fornecedor (
    id_fornecedor_dw BIGINT PRIMARY KEY,
    id_pessoa INTEGER,
    origem_principal VARCHAR(30),
    nome VARCHAR(255),
    cidade VARCHAR(100),
    estado VARCHAR(100),
    pais VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS dm_compras.dim_produto (
    id_produto_dw BIGINT PRIMARY KEY,
    id_produto INTEGER,
    origem_principal VARCHAR(30),
    produto VARCHAR(255),
    categoria VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS dm_compras.fato_compras (
    id_fato_compra_dw BIGINT PRIMARY KEY,

    id_tempo INTEGER NOT NULL,
    id_fornecedor_dw BIGINT NOT NULL,
    id_produto_dw BIGINT NOT NULL,

    data_pedido DATE NOT NULL,
    data_entrada DATE,

    quantidade NUMERIC(18,4) NOT NULL,
    valor_unitario NUMERIC(18,4) NOT NULL,
    valor_total NUMERIC(18,4) NOT NULL,

    id_origem_registro VARCHAR(100),
    sistema_origem VARCHAR(50)
);

-- ============================================================
-- 5. DATA MART 3 - ESTOQUE
-- STAR SCHEMA
-- ============================================================

CREATE TABLE IF NOT EXISTS dm_estoque.dim_tempo (
    id_tempo INTEGER PRIMARY KEY,
    data_completa DATE NOT NULL,
    dia INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    nome_mes VARCHAR(20),
    trimestre INTEGER,
    semestre INTEGER,
    semana_ano INTEGER,
    ano INTEGER,
    dia_semana INTEGER,
    nome_dia_semana VARCHAR(20),
    fim_de_semana BOOLEAN,
    feriado BOOLEAN
);

CREATE TABLE IF NOT EXISTS dm_estoque.dim_produto (
    id_produto_dw BIGINT PRIMARY KEY,
    id_produto INTEGER,
    origem_principal VARCHAR(30),
    produto VARCHAR(255),
    categoria VARCHAR(255),
    fornecedor VARCHAR(255),
    unidades_estoque INTEGER,
    unidades_em_pedido INTEGER,
    nivel_reposicao INTEGER,
    descontinuado BOOLEAN
);

CREATE TABLE IF NOT EXISTS dm_estoque.dim_fonte_dado (
    id_fonte_dw BIGINT PRIMARY KEY,
    sistema_origem VARCHAR(100),
    tabela_origem VARCHAR(100),
    tipo_fonte VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dm_estoque.fato_estoque (
    id_fato_estoque_dw BIGINT PRIMARY KEY,

    id_produto_dw BIGINT NOT NULL,
    id_tempo INTEGER NOT NULL,
    id_fonte_dw BIGINT,

    quantidade_estoque NUMERIC(18,4),
    quantidade_em_pedido NUMERIC(18,4),
    nivel_reposicao NUMERIC(18,4),
    valor_estoque NUMERIC(18,4),

    id_origem_registro VARCHAR(100),
    sistema_origem VARCHAR(50)
);

-- ============================================================
-- FIM DO DDL
--
-- ETL posterior:
-- 1. Extrair Mercearia, Northwind e Dados Externos.
-- 2. Preservar as chaves id_ das fontes.
-- 3. Padronizar domínios, tipos, datas e unidades.
-- 4. Carregar dimensões do DW.
-- 5. Carregar fatos no menor nível de granularidade necessário.
-- 6. Popular os 3 Data Marts a partir do DW Organizacional.
-- ============================================================
