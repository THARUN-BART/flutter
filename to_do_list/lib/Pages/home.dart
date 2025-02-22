import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:to_do_list/auth/Login.dart';
import '/auth/Login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _userName = 'User';
  int _selectedIndex = 0; // Navigation index

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchUserName() async {
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            _userName = userDoc['name'] ?? 'User';
          });
        }
      } catch (e) {
        print('Error fetching user name: $e');
      }
    }
  }

  void _updateUserName(String newName) async {
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'name': newName}).then((_) {
        if (mounted) {
          setState(() {
            _userName = newName;
          });
          _showSnackBar("Name Updated!");
        }
      }).catchError((error) {
        if (mounted) _showSnackBar("Failed to update name: $error");
      });
    }
  }

  void _updateTask(String taskId, String currentTask) {
    TextEditingController taskController =
        TextEditingController(text: currentTask);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(taskId.isEmpty ? "Add Task" : "Edit Task"),
          content: TextField(
            controller: taskController,
            decoration: InputDecoration(
              labelText: "Task Name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (taskController.text.isNotEmpty) {
                  if (taskId.isEmpty) {
                    // Add new task
                    FirebaseFirestore.instance.collection('tasks').add({
                      'task': taskController.text,
                      'userId': user!.uid,
                      'completed': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    }).then((_) {
                      if (mounted) _showSnackBar('Task Added');
                    }).catchError((error) {
                      if (mounted) _showSnackBar('Failed to add task: $error');
                    });
                  } else {
                    // Update existing task
                    FirebaseFirestore.instance
                        .collection('tasks')
                        .doc(taskId)
                        .update({'task': taskController.text}).then((_) {
                      if (mounted) _showSnackBar('Task Updated');
                    }).catchError((error) {
                      if (mounted)
                        _showSnackBar('Failed to update task: $error');
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(taskId.isEmpty ? "Add" : "Update"),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateNameDialog() {
    TextEditingController nameController =
        TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Update Name"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: "Enter new name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _updateUserName(nameController.text);
                  Navigator.pop(context);
                }
              },
              child: Text("Update"),
            ),
          ],
        );
      },
    );
  }

  String _getGreetingMessage() {
    int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning, $_userName!';
    } else if (hour < 18) {
      return 'Good Afternoon, $_userName!';
    } else {
      return 'Good Evening, $_userName!';
    }
  }

  Stream<QuerySnapshot> _getTaskStream() {
    if (user == null) return Stream.empty();
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: user!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildHomeScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_getGreetingMessage(), style: TextStyle(fontSize: 18)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getTaskStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snapshot.data!.docs.map((doc) {
                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      FirebaseFirestore.instance
                          .collection('tasks')
                          .doc(doc.id)
                          .delete()
                          .then((_) {
                        if (mounted) _showSnackBar('Task Deleted');
                      }).catchError((error) {
                        if (mounted)
                          _showSnackBar('Failed to delete task: $error');
                      });
                    },
                    child: ListTile(
                      title: Text(
                        doc['task'],
                        style: TextStyle(
                          decoration: doc['completed']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      leading: Checkbox(
                        value: doc['completed'],
                        onChanged: (bool? newValue) {
                          FirebaseFirestore.instance
                              .collection('tasks')
                              .doc(doc.id)
                              .update({'completed': newValue ?? false});
                        },
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _updateTask(doc.id, doc['task']),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileScreen() {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Profile",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                Text("Email: ${user?.email ?? 'Not Available'}",
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                Text("Name: $_userName", style: TextStyle(fontSize: 16)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showUpdateNameDialog,
                  child: Text("Update Name"),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              });
            },
            icon: Icon(Icons.logout_outlined, color: Colors.white),
            label: Text("Log Out", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Red button color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "To-Do List" : "Profile"),
        centerTitle: true,
      ),
      body: _selectedIndex == 0 ? _buildHomeScreen() : _buildProfileScreen(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _updateTask('', ''),
              icon: Icon(Icons.add),
              label: Text("Add Task"),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
