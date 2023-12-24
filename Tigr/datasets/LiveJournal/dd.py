# Path to the file
file_path = 'dense.txt'

# Reading the file
with open(file_path, 'r') as file:
    file_content = file.read()

# Splitting the file content into lines and then into columns
lines = file_content.split('\n')
data = [line.split('\t') for line in lines if line]

# Converting strings to integers
data = [[int(column) for column in row] for row in data]

# Sorting the data
sorted_data = sorted(data, key=lambda x: x[0])

# Preparing the sorted data for writing
sorted_content = '\n'.join(['\t'.join(map(str, row)) for row in sorted_data])

# Writing the sorted data back to the original file
with open(file_path, 'w') as file:
    file.write(sorted_content)
