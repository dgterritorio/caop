-- Instalacao de extensoes

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Schema para guardar tabelas de dominios não editaveis a usar como reference em tabelas editaveis
-- talvez faca sentido deixar de fora ou noutro dominio as tabelas de relacao que podem ser editadas,
-- por exemplo as freguesias e concelhos podem ser alteradas as designacoes, ou mesmo necessitar da criação de novos códigos.
-- sendo portanto de alguma forma editaveis e precisam de ter controlo de versões

-- Schema para guardar lista de valores a usar nas tabelas editáveis
CREATE SCHEMA dominios;
COMMENT ON SCHEMA dominios IS 'Schema para guardar lista de valores a usar nas tabelas editáveis';

CREATE TABLE dominios.tipo_fonte (
	identificador varchar(3) PRIMARY KEY,
	descricao VARCHAR NOT NULL
);

CREATE TABLE dominios.significado_linha (
	identificador varchar(3) PRIMARY KEY,
	descricao VARCHAR NOT NULL
);

CREATE TABLE dominios.estado_limite_administrativo(
	identificador varchar(3) PRIMARY KEY,
	descricao VARCHAR NOT NULL);

CREATE TABLE dominios.nivel_limite_administrativo (
	identificador varchar(3) PRIMARY KEY,
	descricao VARCHAR NOT NULL);

CREATE TABLE dominios.tipo_area_administrativa (
	identificador varchar(3) PRIMARY KEY,
	descricao VARCHAR NOT NULL);

CREATE TABLE dominios.caracteres_identificadores_pais (
	identificador varchar(3) PRIMARY KEY,
	descricao VARCHAR NOT NULL);


-- Schema com as tabelas de base, editáveis e sob versionamento
CREATE SCHEMA base;
COMMENT ON SCHEMA base IS 'Schema com as tabelas de base, editáveis e sob versionamento';

CREATE TABLE base.nuts1 (
identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(),
codigo varchar(3) UNIQUE NOT NULL,
nome varchar UNIQUE NOT NULL
);

CREATE TABLE base.nuts2 (
identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(), --necessário, ou não?
codigo varchar(4) UNIQUE NOT NULL,
nome varchar UNIQUE NOT NULL,
nuts1_cod varchar(3) REFERENCES base.nuts1(codigo) NOT NULL
);

CREATE TABLE base.nuts3 (
identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(),
codigo varchar(5) UNIQUE NOT NULL,
nome varchar UNIQUE NOT NULL,
nuts2_cod varchar(4) REFERENCES base.nuts2(codigo) NOT NULL
);

CREATE TABLE base.distrito_ilha (
identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(), 
di varchar(2) UNIQUE NOT NULL,
nome varchar NOT NULL,
nuts3_cod varchar(3) REFERENCES base.nuts3(codigo) NOT NULL
);

CREATE TABLE base.municipio (
identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(), 
dico varchar(4) UNIQUE NOT NULL,
nome VARCHAR NOT NULL,
distrito_di varchar(2) REFERENCES base.distrito_ilha(di) NOT NULL -- sugestao relacao com os distritos- ilhas
);
-- TODO: criar check constraint the obrigue a que o dico bata certo com o di se este tiver preenchido

-- Tabela das entidades administratvas alimentadas por duas tabelas filhas, freguesias e outras_entidades
CREATE TABLE base.entidade_administrativa (
identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(), 
cod VARCHAR(8) UNIQUE NOT NULL, -- para as freguesias isto equivale ao dicofre
nome VARCHAR NOT NULL
);

CREATE TABLE base.freguesia (
	municipio_dico VARCHAR(4) REFERENCES base.municipio(dico) NOT NULL
) INHERITS (base.entidade_administrativa)
;

ALTER TABLE base.freguesia
ADD CONSTRAINT freguesia_cod_key UNIQUE (cod);
-- TODO: criar check constraint the obrigue a que o dicofre (cod) bata certo com o dico se este tiver preenchido

CREATE TABLE base.outras_entidades ()
INHERITS (base.entidade_administrativa)
;

CREATE TABLE base.fontes (
	identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(),
	tipo_fonte varchar(3) REFERENCES dominios.tipo_fonte(identificador),
	descricao VARCHAR(255) NOT NULL,
	data date NOT NULL DEFAULT now(),
	observacoes VARCHAR,
	diploma VARCHAR(255)
);

CREATE TABLE base.trocos (
	identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(),
	ea_direita VARCHAR(8) REFERENCES base.entidade_administrativa(cod), -- será que é necessário ou podemos preencher à posteriori na tabela de exportação?
	ea_esquerda VARCHAR(8) REFERENCES base.entidade_administrativa(cod),
	pais VARCHAR(3) REFERENCES dominios.caracteres_identificadores_pais(identificador), -- ICC
	estado_limite_admin VARCHAR(3) REFERENCES dominios.estado_limite_administrativo(identificador), --BST
	significado_linha VARCHAR(3) REFERENCES dominios.significado_linha(identificador), --MOL
	nivel_limite_admin VARCHAR(3) REFERENCES dominios.nivel_limite_administrativo(identificador), --USE
	comprimento_m numeric(15,3), -- area calculada pela geometria no plano
	fonte_id uuid REFERENCES base.fontes(identificador), -- relação com a fonte de dados NOT NULL??
	troco_parente uuid, -- para guardar relacao com troco original em caso de cortes 
	             -- tem de ser criada uma referencia para os trocos apagados
	             -- vamos precisar de uma ferramenta especifica para fazer o split
	geometria geometry(LINESTRING, 3763)
);

-- TODO CHECK ea_direita != ea_esquerda

CREATE TABLE base.centroide_ea ( 
	identificador uuid PRIMARY KEY DEFAULT uuid_generate_v1mc(),
	entidade_administrativa VARCHAR(8) REFERENCES base.entidade_administrativa(cod),
	tipo_area_administrativa_id VARCHAR(3) REFERENCES dominios.tipo_area_administrativa(identificador),
	geometria geometry(POINT, 3763) NOT NULL
);

CREATE SCHEMA VERSIONING;

-- Ideia, adicionar um genero de tag, com uma data especifica para guardar as releases.
-- basicamente uma release é a base de dados um determinado instante, guardar essa data com uma descrições
-- pode ser o suficiente para recuperar/recriar/visualizar a base de dados naquele instante

CREATE TABLE VERSIONING.versoes (
	versao VARCHAR(8) PRIMARY KEY,
	descricao VARCHAR(255) NOT NULL,
	data_hora timestamp NOT NULL DEFAULT now(),
	data_publicação timestamp
);

-- Falta criar uma função que adicione versioning nas tabelas que desejarmos.
-- Guardamos utilizador, timestamp. Falámos em guardar o motivo da alteração, mas ainda não pensei como o fazer


-- Criar grupos de utilizadores
CREATE ROLE administrador; -- sugiro este papel para aqueles que tenham de alterar por exemplo a tabela das entidades
CREATE ROLE editor;
CREATE ROLE visualizador;


-- falta criar as funçoes que, dada uma determinada versao da base de dados crie um schema 
-- e respectivas tabelas de output com as geometria, que incluirão:
-- NUT1, NUT2, NUT3
-- Distrito_ilhas 
-- Concelho
-- Freguesia
-- Trocos (eventualmente com os niveis)
-- 

--inicio_objecto timestamp NOT NULL DEFAULT now(),
--fim_objeto timestamp,
--utilizador varchar(255),
--motivo_edicao varchar(255)
