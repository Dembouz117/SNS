#!/bin/bash

echo "Testing Social Network Server..."
echo "================================"
echo ""

# Clean up any existing test data
rm -rf anthony saorla mary 2>/dev/null

echo "Test 1: Create users"
echo "--------------------"
./create_user anthony
./create_user saorla
./create_user mary
echo ""

echo "Test 2: Try to create existing user"
echo "------------------------------------"
./create_user anthony
echo ""

echo "Test 3: Create user without parameter"
echo "--------------------------------------"
./create_user
echo ""

echo "Test 4: Add friends"
echo "-------------------"
./add_friend anthony saorla
./add_friend mary saorla
echo ""

echo "Test 5: Try to add non-existent user as friend"
echo "-----------------------------------------------"
./add_friend anthony nonexistent
echo ""

echo "Test 6: Post messages"
echo "---------------------"
./post_message mary saorla "what's up?"
./post_message anthony saorla "Hey there!"
echo ""

echo "Test 7: Try to post from non-friend"
echo "------------------------------------"
./post_message saorla mary "This should fail"
echo ""

echo "Test 8: Display wall"
echo "--------------------"
./display_wall saorla
echo ""

echo "Test 9: Display wall of user that doesn't exist"
echo "------------------------------------------------"
./display_wall nonexistent
echo ""

echo "Test 10: Verify file structure"
echo "-------------------------------"
echo "Anthony's directory:"
ls -la anthony/
echo ""
echo "Saorla's friends:"
cat saorla/friends
echo ""
echo "Saorla's wall:"
cat saorla/wall
echo ""

echo "All tests completed!"