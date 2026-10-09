# Ensamble: clusterização de clientes com Regras de Associação
### Autores: Flávio Lourenço da Silva e Gustavo Adolpho Souteras Barbosa
### Prof. Dr. Sirlon Diniz
### Data: 8 de outubro de 2026

# Ensamble: clusterização de clientes com Regras de Associação
- Clusterização de clientes com base no perfil de compras;
- Identificação de padrões de associação entre produtos;
- Segmentação de clientes com base em seus hábitos de consumo.

# Criar ambiente virtual

```bash
python -m venv .venv
```

# Ativar ambiente virtual

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

```powershell
.\.venv\Scripts\activate
```

```powershell
.\.venv\Scripts\Activate.ps1
```

# Instalação de dependências

```bash
pip install pandas numpy scikit-learn sqlalchemy psycopg2-binary mlxtend minisom
```

# Executar o script

```bash
python main.py
```

# Executar script em modo silencioso

```bash
python main.py > /dev/null
```

# Criar o arquivo requirements.txt

```bash
pip freeze > requirements.txt
```

# Desativar ambiente virtual

```bash
deactivate
```