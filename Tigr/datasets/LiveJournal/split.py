# Re-importing the file path and redefining the necessary variables and functions
file_path = '/root/Tigr/datasets/LiveJournal/soc-LiveJournal1.txt'
dense_file_path = './dense.txt'
sparse_file_path = './sparse.txt'
order_file_path = '/root/rabbit_order/demo/order.txt'

# COMM_SIZE 값 정의
COMM_SIZE = 256

# order.txt 파일에서 새로운 번호 매핑 읽기
with open(order_file_path, 'r') as file:
    order_data = [int(line.strip()) for line in file if line.strip()]

# 같은 커뮤니티에 속하는지 확인하는 함수
def same_community(node1, node2, comm_size):
    return node1 // comm_size == node2 // comm_size

# soc-LiveJournal1.txt 파일 처리 및 새로운 파일 생성
with open(file_path, 'r') as file, \
     open(dense_file_path, 'w') as dense_file, \
     open(sparse_file_path, 'w') as sparse_file:

    # 실제 order 데이터로 버텍스 매핑 업데이트
    vertex_mapping = {old_vertex: new_vertex for old_vertex, new_vertex in enumerate(order_data)}

    for line in file:
        # 주석 무시
        if line.startswith('#'):
            continue

        # 라인에서 노드 추출 및 새로운 번호로 매핑
        from_node, to_node = map(int, line.split())
        mapped_from_node = vertex_mapping.get(from_node, from_node)
        mapped_to_node = vertex_mapping.get(to_node, to_node)

        # 커뮤니티에 따라 적절한 파일에 쓰기
        if same_community(mapped_from_node, mapped_to_node, COMM_SIZE):
            dense_file.write(f"{mapped_from_node}\t{mapped_to_node}\n")
        else:
            sparse_file.write(f"{mapped_from_node}\t{mapped_to_node}\n")