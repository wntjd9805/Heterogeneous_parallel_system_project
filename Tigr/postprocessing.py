# 재정의된 파일 경로 및 변수

import time

start_time = time.time()

file_path = '/root/Tigr/datasets/Pokec/soc-pokec-relationships.txt'
order_file_path = '/root/rabbit_order/demo/soc-pokec-relationships_order.txt'
combined_file_path = './reordered_soc-pokec-relationships.txt'  # 모든 노드 쌍을 저장할 파일 경로

# order.txt 파일에서 새로운 번호 매핑 읽기
with open(order_file_path, 'r') as file:
    order_data = [int(line.strip()) for line in file if line.strip()]

# soc-LiveJournal1.txt 파일 처리 및 새로운 파일 생성
with open(file_path, 'r') as file, open(combined_file_path, 'w') as combined_file:
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

        # 모든 노드 쌍을 단일 파일에 저장
        combined_file.write(f"{mapped_from_node}\t{mapped_to_node}\n")

# 파일이 성공적으로 생성되었는지 확인
"Combined nodes file created successfully at: " + combined_file_path
# 측정하고 싶은 코드
# 예: time.sleep(2)

end_time = time.time()
elapsed_time = end_time - start_time
print(f"{elapsed_time} seconds elapsed.")