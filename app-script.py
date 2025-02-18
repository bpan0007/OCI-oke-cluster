def main():
    print("Hello from the pipeline!")
    
    # Simulate some basic deployment tasks
    deployment_steps = [
        "Checking dependencies",
        "Running tests",
        "Building artifact",
        "Deploying to environment"
    ]
    
    for step in deployment_steps:
        print(f"Step: {step}")

if __name__ == "__main__":
    main()