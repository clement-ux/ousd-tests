import json

# Load the JSON file
json_file = 'test/invariants/multi-fuzzer/out/medusa/call_sequences/1733221892688394000-a39681a7-0e3e-4de7-bee2-818a6980cfcd.json'
with open(json_file, 'r') as file:
    data = json.load(file)

# Extract and format the calls
formatted_calls = []
for item in data:
    call_data = item.get('call', {}).get('dataAbiValues', {})
    method_signature = call_data.get('methodSignature')
    input_values = call_data.get('inputValues', [])
    if method_signature and input_values:
        method_name = method_signature.split('(')[0]
        formatted_call = f"try f.{method_name}({', '.join(input_values)}) {{}} catch {{}}"
        formatted_calls.append(formatted_call)

# Generate the final text
result = "\n".join(formatted_calls)

# Print the result
print("Formatted calls:")
print(result)
