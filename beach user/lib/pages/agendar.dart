import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'agendamentos.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgendarPage extends StatefulWidget {
  final Agendamento? agendamento;
  final int? index;

  AgendarPage({Key? key, this.agendamento, this.index}) : super(key: key);
  @override
  _AgendarPageState createState() => _AgendarPageState();
}

class _AgendarPageState extends State<AgendarPage> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedStartTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay selectedEndTime = TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    if (widget.agendamento != null) {
      
      selectedDate = widget.agendamento!.data;
      selectedStartTime = widget.agendamento!.horaInicio;
      selectedEndTime = widget.agendamento!.horaFim;
    }
  }

  double _calcularValor(TimeOfDay inicio, TimeOfDay fim) {
  
    final int minutosInicio = inicio.hour * 60 + inicio.minute;
    final int minutosFim = fim.hour * 60 + fim.minute;

    final int diferencaMinutos = minutosFim - minutosInicio;

  
    final double valorPorMinuto = 0.5;

    return diferencaMinutos * valorPorMinuto;
  }

  Future<void> _salvarAgendamento() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      String uniqueId = widget.agendamento?.documentId ?? Uuid().v4();
      CollectionReference agendamentosCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('agendamentos');

      DateTime data = selectedDate;
      TimeOfDay horaInicio = selectedStartTime;
      TimeOfDay horaFim = selectedEndTime;

      double valor = _calcularValor(horaInicio, horaFim);

      // Verifica conflitos de horário
      /* bool horarioDisponivel = await _verificarDisponibilidadeHorario(
        data,
        horaInicio,
        horaFim,
      );
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      if (!horarioDisponivel) {
        _exibirMensagemErro('Horário indisponível. Escolha outro horário.');
        return;
      }*/

   
      await agendamentosCollection.doc(uniqueId).set({
        'id': uniqueId,
        'data': selectedDate,
        'horaInicio': _formatTimeOfDay(selectedStartTime),
        'horaFim': _formatTimeOfDay(selectedEndTime),
        'valor': _calcularValor(selectedStartTime, selectedEndTime),
      });

      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AgendamentosPage()),
      );
    } catch (e) {
      print('Erro ao salvar agendamento: $e');
      _exibirMensagemErro('Erro ao salvar agendamento. Tente novamente.');
    }
  }

  /* Future<bool> _verificarDisponibilidadeHorario(
    DateTime data,
    TimeOfDay horaInicio,
    TimeOfDay horaFim,
  ) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('agendamentos')
              .where('data', isEqualTo: data)
              .get();

      for (QueryDocumentSnapshot<Map<String, dynamic>> doc
          in querySnapshot.docs) {
        TimeOfDay agendamentoHoraInicio =
            _parseTimeOfDay(doc['horaInicio'] as String);
        TimeOfDay agendamentoHoraFim =
            _parseTimeOfDay(doc['horaFim'] as String);

        if (_verificarConflitoHorario(
          horaInicio,
          horaFim,
          agendamentoHoraInicio,
          agendamentoHoraFim,
        )) {
          return false; 
        }
      }

      return true; 
    } catch (e) {
      print('Erro ao verificar disponibilidade de horário: $e');
      return false;
    }
  }

  bool _verificarConflitoHorario(
    TimeOfDay novoInicio,
    TimeOfDay novoFim,
    TimeOfDay existenteInicio,
    TimeOfDay existenteFim,
  ) {
    int novoInicioMinutos = novoInicio.hour * 60 + novoInicio.minute;
    int novoFimMinutos = novoFim.hour * 60 + novoFim.minute;
    int existenteInicioMinutos =
        existenteInicio.hour * 60 + existenteInicio.minute;
    int existenteFimMinutos = existenteFim.hour * 60 + existenteFim.minute;

   
    if (novoInicioMinutos >= existenteInicioMinutos &&
        novoFimMinutos <= existenteFimMinutos) {
      return true;
    }

    
    if (existenteInicioMinutos >= novoInicioMinutos &&
        existenteFimMinutos <= novoFimMinutos) {
      return true;
    }

   
    if ((novoInicioMinutos < existenteFimMinutos &&
            novoFimMinutos > existenteInicioMinutos) ||
        (existenteInicioMinutos < novoFimMinutos &&
            existenteFimMinutos > novoInicioMinutos)) {
      return true;
    }

    return false; 
  }*/

  TimeOfDay _parseTimeOfDay(String formattedTime) {
    List<String> parts = formattedTime.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  void _exibirMensagemErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime currentDate = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: currentDate,
      lastDate: DateTime(2101),
    );

    if (picked != null &&
        picked != selectedDate &&
        picked.isAfter(currentDate)) {
      setState(() {
        selectedDate = picked;
      });
    } else if (picked != null && picked != selectedDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione uma data futura.'),
        ),
      );
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedStartTime) {
      TimeOfDay minimumTime = TimeOfDay(hour: 8, minute: 0);

      if (picked.hour < minimumTime.hour ||
          (picked.hour == minimumTime.hour &&
              picked.minute < minimumTime.minute)) {
       
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selecione um horário válido a partir de 08:00.'),
          ),
        );
      } else {
        
        setState(() {
          selectedStartTime = picked;
        });
      }
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedEndTime) {
      TimeOfDay minimumTime = TimeOfDay(hour: 8, minute: 59);
      TimeOfDay maximumTime = TimeOfDay(hour: 23, minute: 59);

      if (picked.hour < minimumTime.hour ||
          (picked.hour == minimumTime.hour &&
              picked.minute < minimumTime.minute)) {
        setState(() {
          selectedEndTime = minimumTime;
        });
      } else if (picked.hour > maximumTime.hour ||
          (picked.hour == maximumTime.hour &&
              picked.minute > maximumTime.minute)) {
        setState(() {
          selectedEndTime = maximumTime;
        });
      } else {
        setState(() {
          selectedEndTime = picked;
        });

        if (picked.hour < selectedStartTime.hour ||
            (picked.hour == selectedStartTime.hour &&
                picked.minute <= selectedStartTime.minute)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Selecione um horário válido a partir de 09:00 e até às 00:00.')),
          );
        }
      }
    }
  }

  ElevatedButton _buildElevatedButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        primary: Colors.white,
        onPrimary: Color.fromARGB(255, 244, 129, 33),
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        side: BorderSide(
          color: Color.fromARGB(255, 244, 129, 33),
          width: 4.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0), 
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 20.0),
      ),
    );
  }

  void _agendar() async {
    await _salvarAgendamento();
  }

  @override
  Widget build(BuildContext context) {
    Agendamento? agendamento = widget.agendamento;
    int? index = widget.index;
    return Scaffold(
      appBar: null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black87,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 50.0),
              Text(
                'Agende seu horário',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 244, 129, 33),
                ),
              ),
              SizedBox(height: 16.0),
              Column(
                children: [
                  SizedBox(height: 16.0),
                  Text(
                    'Selecione a data:',
                    style: TextStyle(fontSize: 18.0, color: Colors.white),
                  ),
                  SizedBox(height: 8.0),
                  _buildElevatedButton(
                    DateFormat('dd/MM/yyyy').format(selectedDate),
                    () => _selectDate(context),
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    'Selecione a hora de início:',
                    style: TextStyle(fontSize: 18.0, color: Colors.white),
                  ),
                  SizedBox(height: 8.0),
                  _buildElevatedButton(
                    _formatTimeOfDay(selectedStartTime),
                    () => _selectStartTime(context),
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    'Selecione a hora de término:',
                    style: TextStyle(fontSize: 18.0, color: Colors.white),
                  ),
                  SizedBox(height: 8.0),
                  _buildElevatedButton(
                    _formatTimeOfDay(selectedEndTime),
                    () => _selectEndTime(context),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Center(
                child: Container(
                  height: 50.0,
                  child: ElevatedButton(
                    onPressed: _agendar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 244, 129, 33),
                      padding: EdgeInsets.symmetric(horizontal: 40.0),
                    ),
                    child: Text(
                      'Agendar',
                      style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16.0),
        color: Colors.black87,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 80.0,
            ),
          ],
        ),
      ),
    );
  }
}
