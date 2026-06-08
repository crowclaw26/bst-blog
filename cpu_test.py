import platform

print("--- Basic CPU Info ---")
print(f"Processor: {platform.processor()}")
print(f"Architecture: {platform.architecture()[0]}")
print(f"Machine: {platform.machine()}")
