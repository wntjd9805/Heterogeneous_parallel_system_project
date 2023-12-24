# Heterogeneous_parallel_system_project


### Build rabbit order and Tigr
```jsx
cd /root/Heterogeneous_parallel_system_project/Tigr/
make
cd /root/Heterogeneous_parallel_system_project
git clone https://github.com/araij/rabbit_order.git
cd /root/Heterogeneous_parallel_system_project/rabbit_order
make
```

Make in Tigr/datasets to get the data
```jsx
cd /root/Heterogeneous_parallel_system_project/Tigr/datasets/Pokec
make
```
### reordering
An orderer file already exists for your data in /root/Heterogeneous_parallel_system_project/rabbit_order/demo. If you want to create one, enter the following command

```jsx
Usage: reorder [-c] GRAPH_FILE
  -c    Print community IDs instead of a new ordering
example : ./reorder /root/Tigr/datasets/Pokec/soc-pokec-relationships.txt >> soc-pokec-relationships_order.txt
```
### postprocessing

```jsx
cd /root/Heterogeneous_parallel_system_project/Tigr/postprocessing.py
python postprocession
```

### Run
```jsx
./pr --input /root/Tigr/datasets/Pokec/soc-pokec-relationships.txt  --source 1   
./pr --input /root/Tigr/reordered_soc-pokec-relationships.txt --source 692229    
```
