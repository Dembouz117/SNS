#!/bin/bash

echo "Testing Social Network Server (Interactive Mode)"
echo "================================================="
echo ""

# Clean up any existing test data
rm -rf alice bob carol test_user 2>/dev/null

# Create a test input file
cat > server_commands.txt << 'EOF'
create alice
create bob
create carol
add alice bob
add alice carol
post alice bob Hello from Alice!
post alice carol Hi Carol!
display bob
display carol
create test_user
display test_user
bad_command
exit
EOF

echo "Running server with test commands..."
echo ""

# Run the server with input from file
./server < server_commands.txt

echo ""
echo "Test completed!"
echo ""
echo "Verifying results:"
echo "=================="

echo ""
echo "Alice's friends:"
cat alice/friends 2>/dev/null || echo "(none)"

echo ""
echo "Bob's friends:"
cat bob/friends 2>/dev/null || echo "(none)"

echo ""
echo "Bob's wall:"
cat bob/wall 2>/dev/null || echo "(empty)"

echo ""
echo "Carol's wall:"
cat carol/wall 2>/dev/null || echo "(empty)"

echo ""
echo "Cleanup test files..."
rm -f server_commands.txt