import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  List<dynamic> data = [];
  String _selectedSourceLanguage = '';
  String _selectedTargetLanguage = '';
  String _outputText = '';
  String _sourceLanguage = '';
  List<String> translationHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchSupportedLanguages();
    _loadTranslationHistory();
  }

  Future<void> _fetchSupportedLanguages() async {
    final response = await http.get(
      Uri.parse(
        'https://google-translate113.p.rapidapi.com/api/v1/translator/support-languages',
      ),
      headers: {
        'X-RapidAPI-Key': 'f33b805ccdmshec4c67929283b7cp1ac331jsn92a7ae8d08d1',
        'X-RapidAPI-Host': 'google-translate113.p.rapidapi.com',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        data = json.decode(response.body);
        // Set initial values if needed
        _selectedSourceLanguage =
            data.isNotEmpty ? data[0]['code'].toString() : '';
        _selectedTargetLanguage =
            data.isNotEmpty ? data[0]['code'].toString() : '';
      });
    } else {
      print(
          'Failed to fetch supported languages. Status code: ${response.statusCode}');
    }
  }

  Future<void> _translateText() async {
    if (_inputController.text.isEmpty || _selectedTargetLanguage.isEmpty) {
      print('Input text or target language is empty');
      return;
    }

    try {
      print('Request body: ${json.encode({
            'from':
                _selectedSourceLanguage, // Remove or set to an empty string for auto-detection
            'to': _selectedTargetLanguage,
            'text': _inputController.text, // Use input text as source text
          })}');

      final response = await http.post(
        Uri.parse(
          'https://google-translate113.p.rapidapi.com/api/v1/translator/text',
        ),
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          'X-RapidAPI-Key':
              'f33b805ccdmshec4c67929283b7cp1ac331jsn92a7ae8d08d1',
          'X-RapidAPI-Host': 'google-translate113.p.rapidapi.com',
        },
        body: {
          'from':
              _selectedSourceLanguage, // Remove or set to an empty string for auto-detection
          'to': _selectedTargetLanguage,
          'text': _inputController.text, // Use input text as source text
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('trans')) {
          final String translatedText = data['trans'];
          setState(() {
            _outputText = translatedText;
            _outputController.text =
                translatedText; // Set translated text to the output field
          });

          // Save the translation to history
          _addToTranslationHistory(
              '${_inputController.text} -> $translatedText');
        } else {
          print('Missing "trans" field in the response');
        }
      } else {
        print(
            'Failed to load translation. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during translation request: $e');
    }
  }

  Future<void> _addToTranslationHistory(String translation) async {
    // Save the translation to history list
    translationHistory.add(
        '${_selectedSourceLanguage}${_selectedTargetLanguage}$translation');

    // Save the updated history to persistent storage
    await _saveTranslationHistory();
  }

  Future<void> _saveTranslationHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('translationHistory', translationHistory);
  }

  Future<void> _loadTranslationHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? loadedHistory = prefs.getStringList('translationHistory');
    if (loadedHistory != null) {
      setState(() {
        translationHistory = loadedHistory;
      });
    }
  }

  Future<void> _clearTranslationHistory() async {
    // Clear the translation history
    setState(() {
      translationHistory = [];
    });

    // Save the updated empty history to persistent storage
    await _saveTranslationHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Translator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        labelText: 'Enter Text',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.volume_up),
                          onPressed: () => _speakText(_inputController.text),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$_sourceLanguage'),
                        Flexible(
                          child: DropdownButton<String>(
                            value: _selectedSourceLanguage,
                            onChanged: (String? newValue) {
                              print('$newValue');
                              setState(() {
                                _selectedSourceLanguage = newValue!;
                              });
                            },
                            items: data
                                .map<DropdownMenuItem<String>>((dynamic value) {
                              return DropdownMenuItem<String>(
                                value: value['code'].toString(),
                                child: Text(value['language'].toString()),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _outputController,
                      decoration: InputDecoration(
                        labelText: 'Translated Text',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.volume_up),
                          onPressed: () => _speakText(_outputController.text),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$_selectedTargetLanguage'),
                        Flexible(
                          child: DropdownButton<String>(
                            value: _selectedTargetLanguage,
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedTargetLanguage = newValue!;
                              });
                            },
                            items: data
                                .map<DropdownMenuItem<String>>((dynamic value) {
                              return DropdownMenuItem<String>(
                                value: value['code'].toString(),
                                child: Text(value['language'].toString()),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _translateText();
              },
              child: Text('Translate'),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _startListening(_inputController);
                  },
                  child: Icon(Icons.mic),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the History screen with translationHistory
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HistoryScreen(
                translationHistory: translationHistory,
                data: data,
                onClearHistory: _clearTranslationHistory,
              ),
            ),
          );
        },
        tooltip: 'History',
        child: Icon(Icons.history),
      ),
    );
  }

  Future<void> _speakText(String text) async {
    print('Speaking text: $text');
    await flutterTts.speak(text);
  }

  void _startListening(TextEditingController inputController) async {
    bool available = await speech.initialize(
      onStatus: (status) {
        print('Speech to text status: $status');
      },
      onError: (errorNotification) {
        print('Speech to text error: $errorNotification');
      },
    );

    if (available) {
      // Start listening
      speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Update the input text field with the recognized speech
            setState(() {
              inputController.text = result.recognizedWords;
            });
          }
        },
      );
    } else {
      print('Speech to text not available');
    }
  }
}

class HistoryScreen extends StatefulWidget {
  final List<String> translationHistory;
  final List<dynamic> data;
  final Future<void> Function() onClearHistory;

  HistoryScreen({
    required this.translationHistory,
    required this.data,
    required this.onClearHistory,
  });

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String getLanguageName(String languageCode) {
    var language = widget.data.firstWhere(
      (element) => element['code'] == languageCode,
      orElse: () => {'language': 'Unknown'},
    );
    return language['language'].toString();
  }

  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              setState(() {
                _deleting = true;
              });

              await widget
                  .onClearHistory(); // Wait for the operation to complete

              setState(() {
                _deleting = false;
              });
            },
          ),
        ],
      ),
      body: _deleting
          ? Center(
              child: CircularProgressIndicator(),
            )
          : widget.translationHistory.isEmpty
              ? Center(
                  child: Text('No translation history'),
                )
              : ListView.builder(
                  itemCount: widget.translationHistory.length,
                  itemBuilder: (context, index) {
                    List<String> translationInfo =
                        widget.translationHistory[index].split('_');
                    String sourceLanguageCode = translationInfo[0];
                    String targetLanguageCode =
                        translationInfo[0]; // Fix index here
                    String translationText =
                        translationInfo[0]; // Fix index here

                    String sourceLanguageName =
                        getLanguageName(sourceLanguageCode);
                    String targetLanguageName =
                        getLanguageName(targetLanguageCode);

                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From: $sourceLanguageName'),
                            Text('To: $targetLanguageName'),
                            Text('Translation: $translationText'),
                            // Add more information as needed
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
