
full-deployment-package:
	pip install --target ./etl_function/package -r requirements.txt
	cd etl_function/package && zip -r9 ../function.zip .
	cd etl_function && zip -g function.zip main.py
	mv etl_function/function.zip .
