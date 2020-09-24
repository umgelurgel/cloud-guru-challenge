
full-deployment:
	pip install --target ./etl_function/package -r requirements.txt
	cd etl_function/package && zip -r9 ../full_function.zip .
	cd etl_function && zip -g full_function.zip main.py
	mv etl_function/full_function.zip .

lean-layer:
	mkdir -p ./etl_function/layer/python
	pip install --target ./etl_function/layer/python -r requirements.txt
	cd etl_function/layer && zip -r9 ../../lean_layer.zip .

lean-function:
	cd etl_function && zip -9 ../lean_function.zip main.py utils.py

lean-deployment:
	make lean-layer
	make lean-full_function
