import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'agendar.dart';
import 'registro.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

String formatPhoneNumber(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');

  if (digits.length < 10) {
    return phoneNumber;
  }

  return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
}

class AgendamentosPage extends StatefulWidget {
  final Agendamento? novoAgendamento;
  AgendamentosPage({Key? key, this.novoAgendamento}) : super(key: key);

  @override
  _AgendamentosPageState createState() => _AgendamentosPageState();
}

class MyAppUser {
  final String uid;
  String? displayName;
  String? phoneNumber;
  final String? email;

  MyAppUser({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
    this.email,
  });

  factory MyAppUser.fromFirebaseUser(User user) {
    return MyAppUser(
      uid: user.uid,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      email: user.email,
    );
  }
}

class _AgendamentosPageState extends State<AgendamentosPage> {
  String? currentUserId; // Adiciona esta variável global
  List<String> agendamentoDocumentIds = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool isProfileDrawer = false;

  List<Agendamento> agendamentos = [];

  MyAppUser? currentUser;

  void adicionarNovoAgendamento(Agendamento novoAgendamento) {
    setState(() {
      agendamentos.add(novoAgendamento);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<List<Agendamento>> _getAgendamentosFromFirestore() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('agendamentos')
              .get();

      return querySnapshot.docs.map((doc) {
        return Agendamento(
          userId: currentUserId!, 
          documentId: doc.id,
          data: (doc['data'] as Timestamp).toDate(),
          horaInicio: _parseTimeOfDay(doc['horaInicio']),
          horaFim: _parseTimeOfDay(doc['horaFim']),
          valor: doc['valor'] ?? 0.0,
        );
      }).toList();
    } catch (e) {
      print('Erro ao obter agendamentos do Firestore: $e');
      return [];
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    List<String> parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Future<void> _loadUserData() async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      try {
        String userId = firebaseUser.uid; 
        setState(() {
          currentUserId =
              userId; 
        });

        DocumentSnapshot<Map<String, dynamic>> additionalDataDoc =
            await FirebaseFirestore.instance
                .collection('users_additional_data')
                .doc(userId)
                .get();

        if (additionalDataDoc.exists) {
          setState(() {
            currentUser = MyAppUser.fromFirebaseUser(firebaseUser!);
            currentUser?.displayName = additionalDataDoc['name'];
            currentUser?.phoneNumber = additionalDataDoc['phoneNumber'];
          });

          Provider.of<UserData>(context, listen: false).updateUser(
            currentUser?.displayName ?? 'Sem Nome',
            currentUser?.email ?? 'Sem E-mail',
            currentUser?.phoneNumber ?? 'Sem Telefone',
          );
        }
      } catch (e) {
        print("Erro ao obter dados do usuário: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        padding:
            EdgeInsets.only(top: 60.0, left: 10.0, right: 10.0, bottom: 10.0),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Agendamentos',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 244, 129, 33),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () {
                      _scaffoldKey.currentState!.openEndDrawer();
                    },
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Agendamento>>(
                future: _getAgendamentosFromFirestore(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text(
                        'Erro ao carregar agendamentos: ${snapshot.error}');
                  } else {
                    agendamentos = snapshot.data ?? [];
                    print('Quantidade de agendamentos: ${agendamentos.length}');
                    return ListView.builder(
                      itemCount: agendamentos.length,
                      itemBuilder: (context, index) {
                        var agendamento = agendamentos[index];
                        return _buildAgendamentoCard(
                          agendamento.data,
                          agendamento.horaInicio,
                          agendamento.horaFim,
                          agendamento.valor,
                          agendamento.documentId ?? '',
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      endDrawer: isProfileDrawer
          ? _buildProfileDrawer()
          : Drawer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.only(top: 60.0, left: 16.0),
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 244, 129, 33),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isProfileDrawer = true;
                      });
                    },
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Perfil'),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterPage()),
                      );
                    },
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Fazer Logout'),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: FractionalOffset.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Image.asset(
                          'assets/logo2.png',
                          height: 120.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.0,
          ),
        ),
        child: FloatingActionButton(
          backgroundColor: const Color.fromARGB(255, 244, 129, 14),
          onPressed: () async {
            var result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AgendarPage()),
            );

            if (result != null && result is Agendamento) {
              setState(() {
                agendamentos.add(result);
              });
            }
          },
          child: Icon(Icons.add, color: Colors.white),
          shape: CircleBorder(),
        ),
      ),
    );
  }

  Future<void> _adicionarAgendamentoNoFirestore(
      Agendamento novoAgendamento) async {
    try {
      DocumentReference<Map<String, dynamic>> documentReference =
          await FirebaseFirestore.instance
              .collection('users') 
              .doc(currentUserId) 
              .collection(
                  'agendamentos') 
              .add({
        'userId': novoAgendamento.userId, 
        'data': novoAgendamento.data,
        'horaInicio': novoAgendamento.horaInicio.toString(),
        'horaFim': novoAgendamento.horaFim.toString(),
        'valor': novoAgendamento.valor,
      });

      // Obtém o documentId gerado
      String documentId = documentReference.id;

      setState(() {
        novoAgendamento.documentId = documentId;
      });

      print('Agendamento adicionado com ID: $documentId');
    } catch (e) {
      print('Erro ao adicionar agendamento no Firestore: $e');
    }
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.only(top: 50.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      isProfileDrawer = false;
                    });
                  },
                  color: const Color.fromARGB(255, 124, 123, 123),
                ),
                Flexible(
                  child: Text(
                    'Perfil',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 244, 129, 33),
                    ),
                  ),
                ),
                SizedBox(width: 48.0),
              ],
            ),
          ),
          SizedBox(height: 16.0),
          _buildProfileInfo(currentUser),
          Expanded(
            child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Image.asset(
                  'assets/logo2.png',
                  height: 120.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(MyAppUser? user) {
    if (user != null) {
      String name = user.displayName ?? 'Sem Nome';
      String phone = user.phoneNumber != null
          ? formatPhoneNumber(user.phoneNumber!)
          : 'Sem Telefone';
      String email = user.email ?? 'Sem E-mail';

      return FutureBuilder<String>(
        future: _downloadProfileImage(user.uid),
        builder: (context, snapshot) {
          String imageUrl = snapshot.data ?? 'assets/profile.png';

          return Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundImage: NetworkImage(imageUrl),
                  ),
                ),
                SizedBox(height: 16.0),
                Text(
                  'Nome : $name',
                  style: TextStyle(fontSize: 16.0, color: Colors.grey),
                ),
                Text(
                  'Telefone: $phone',
                  style: TextStyle(fontSize: 16.0, color: Colors.grey),
                ),
                Text(
                  'Email: $email',
                  style: TextStyle(fontSize: 16.0, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return Container(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Usuário não logado',
          style: TextStyle(fontSize: 16.0, color: Colors.grey),
        ),
      );
    }
  }

  Future<String> _downloadProfileImage(String userId) async {
    try {
      firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
          .ref('profile_images')
          .child('$userId.jpg');

      String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Erro ao obter a URL da imagem: $e');
      return 'assets/profile.png';
    }
  }

  Widget _buildAgendamentoCard(
    DateTime data,
    TimeOfDay horaInicio,
    TimeOfDay horaFim,
    double valorEmCentavos,
    String documentId, 
  ) {
    Agendamento agendamento = agendamentos.firstWhere(
      (element) => element.documentId == documentId,
    );
    double valor = agendamento.calcularValor();

    return InkWell(
      onTap: () async {
        var result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgendarPage(
              agendamento: agendamento,
            ),
          ),
        );

        if (result != null && result is Agendamento) {
          setState(() {
            int index = agendamentos
                .indexWhere((element) => element.documentId == documentId);
            if (index != -1) {
              agendamentos[index] = result;
            }
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: Card(
          color: Color.fromARGB(255, 244, 129, 33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            child: ListTile(
              contentPadding: EdgeInsets.all(8.0),
              title: SizedBox(
                child: Text(
                  'Data: ${DateFormat('dd/MM/yyyy').format(data)}',
                  style: TextStyle(fontSize: 18.0, color: Colors.white),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horário: ${horaInicio.format(context)} - ${horaFim.format(context)}',
                    style: TextStyle(fontSize: 18.0, color: Colors.white),
                  ),
                  Text(
                    'Valor: R\$ ${valor.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18.0, color: Colors.white),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
                onPressed: () {
                  _excluirAgendamento(agendamentos.indexOf(agendamento));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _adicionarAgendamento() async {
    var result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgendarPage()),
    );

    if (result != null && result is Agendamento) {
     
      setState(() {
        agendamentos.add(result);
      });

      
      await _adicionarAgendamentoNoFirestore(result);
    }
  }

  void _adicionarCardAoAgendamentos(String documentId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('agendamentos')
              .doc(documentId)
              .get();

      if (docSnapshot.exists) {
        Agendamento novoAgendamento = Agendamento(
            data: (docSnapshot['data'] as Timestamp).toDate(),
            horaInicio: _parseTimeOfDay(docSnapshot['horaInicio']),
            horaFim: _parseTimeOfDay(docSnapshot['horaFim']),
            valor: docSnapshot['valor'] ?? 0.0,
            documentId: documentId,
            userId: currentUserId!);

        setState(() {
          agendamentos.add(novoAgendamento);
        });
      }
    } catch (e) {
      print('Erro ao adicionar card ao agendamento: $e');
    }
  }

  Future<void> _excluirAgendamento(int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmação'),
          content: Text('Tem certeza de que deseja excluir este agendamento?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: const Color.fromARGB(255, 244, 129, 33),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                
                if (index >= 0 && index < agendamentos.length) {
                  String? documentId = agendamentos[index].documentId;

                 
                  setState(() {
                    agendamentos.removeAt(index);
                  });

                
                  await _excluirAgendamentoNoFirestore(documentId);

                  Navigator.of(context).pop();
                } else {
                  print(
                      'Erro: O índice está fora dos limites da lista de agendamentos.');
                }
              },
              child: Text(
                'Confirmar',
                style: TextStyle(
                  color: const Color.fromARGB(255, 244, 129, 33),
                ),
              ),
            ),
          ],
        );
      },
    );

   
    return Future.value();
  }

  Future<void> _excluirAgendamentoNoFirestore(String? documentId) async {
    try {
      if (documentId != null) {
        await FirebaseFirestore.instance
            .collection('users') 
            .doc(currentUserId) 
            .collection('agendamentos')
            .doc(documentId)
            .delete();
      } else {
        print('Erro: ID do agendamento é nulo.');
      }
    } catch (e) {
      print('Erro ao excluir agendamento do Firestore: $e');
    }
  }

  Future<String> _getAgendamentoDocumentId(int index) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance.collection('agendamentos').get();

      return querySnapshot.docs[index].id;
    } catch (e) {
      print('Erro ao obter ID do agendamento: $e');
      return '';
    }
  }
}

class Agendamento {
  final String userId;
  String documentId;
  final DateTime data;
  final TimeOfDay horaInicio;
  final TimeOfDay horaFim;
  final double valor;

  Agendamento({
    required this.userId,
    required this.documentId,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.valor,
  });

  int calcularDiferencaMinutos() {
    final int minutosInicio = horaInicio.hour * 60 + horaInicio.minute;
    final int minutosFim = horaFim.hour * 60 + horaFim.minute;
    return minutosFim - minutosInicio;
  }

  double calcularValor() {
    final int diferencaMinutos = calcularDiferencaMinutos();
    final double valorPorMinuto = 0.66;
    return diferencaMinutos * valorPorMinuto;
  }
}
