---
name: simplifyCodeComments
description: Simplify function-level comments to one line while keeping detailed comments inside code.
argument-hint: The file or code to refactor comments for
---
Refactor the comments in the specified code following these principles:

## Comment Organization Rules

1. **Function/Method Level Comments**
   - Use a single concise line describing the function's purpose
   - Remove verbose documentation blocks (parameters, returns, exceptions, flow descriptions)
   - Format: `# Brief description of what this function does`

2. **Inline Comments (Inside Code)**
   - Keep detailed implementation comments within the function body
   - Each significant line or block should have a purpose comment
   - Comments should explain "why" or "what", not repeat the code

3. **What to Remove**
   - Multi-line documentation headers with repeated sections
   - Redundant parameter/return value descriptions
   - Step-by-step flow explanations in header blocks
   - Verbose "side effects" or "exceptions" sections

4. **What to Keep**
   - One-line function description
   - Important implementation notes inside code
   - Comments explaining complex logic or business rules

## Example Transformation

**Before:**
```
# Function: process_data
# Description: Processes the input data and returns results
# Parameters:
#   $1 - input file path
#   $2 - output format
# Returns:
#   0 on success, 1 on failure
# Flow:
#   1. Validate input
#   2. Process data
#   3. Output results
process_data() {
```

**After:**
```
# Process input data and output results in specified format
process_data() {
    # Validate input parameters
    ...
    # Transform data according to rules
    ...
```

Apply this refactoring systematically throughout the file, then verify syntax correctness.
