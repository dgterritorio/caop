# Instruções para gerar a documentação

1. criar um virtualenv com os requisitos

    ```
    python3 -m venv mkdocs_venv
    pip install -r requirements.txt
    ```

2. Activar o virtual environment

   ```
   source mkdocs_venv/bin/activate
   ```

3. Gerar o site que se regenera com as alterações

   ```
   mkdocs serve
   ```