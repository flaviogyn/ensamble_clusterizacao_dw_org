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
pip install pandas numpy scikit-learn sqlalchemy psycopg2-binary mlxtend
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