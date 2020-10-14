
full-deployment:
	pip install --target ./etl_function/package -r requirements.txt
	cd etl_function/package && zip -r9 ../full_function.zip .
	cd etl_function && zip -g full_function.zip main.py
	mv etl_function/full_function.zip .

lean-layer:
	mkdir -p ./etl_function/python
	pip install --upgrade --target ./etl_function/python -r requirements.txt
	cd etl_function && zip -ru9 ../etl_layer.zip ./python

lean-function:
	cd etl_function && zip -u9 ../etl_function.zip main.py utils.py

lean-deployment:
	make lean-layer
	make lean-function
