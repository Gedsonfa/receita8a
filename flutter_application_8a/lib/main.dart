import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum TableStatus { idle, loading, ready, error }

enum ItemType { beer, coffee, nation, none }

class DataService {
  final ValueNotifier<Map<String, dynamic>> tableStateNotifier =
      ValueNotifier({'status': TableStatus.idle, 'dataObjects': []});

  void loadData(Uri uri, ItemType itemType, List<String> propertyNames) {
    //ignorar solicitação se uma requisição já estiver em curso
    if (tableStateNotifier.value['status'] == TableStatus.loading) return;

    //define o estado da tabela para carregar se o tipo de item for diferente
    if (tableStateNotifier.value['itemType'] != itemType) {
      tableStateNotifier.value = {
        'status': TableStatus.loading,
        'dataObjects': [],
        'itemType': itemType
      };
    }

    http.read(uri).then((jsonString) {
      var jsonData = jsonDecode(jsonString);

      //se houver itens existentes no estado da tabela, mescle-os com os novos itens
      if (tableStateNotifier.value['status'] != TableStatus.loading) {
        jsonData = [
          ...tableStateNotifier.value['dataObjects'],
          ...jsonData,
        ];
      }

      tableStateNotifier.value = {
        'itemType': itemType,
        'status': TableStatus.ready,
        'dataObjects': jsonData,
        'propertyNames': propertyNames,
        'columnNames': ["Nome", ...propertyNames]
      };
    });
  }

  void carregar(ItemType itemType) {
    switch (itemType) {
      case ItemType.beer:
        carregarCervejas();
        break;
      case ItemType.coffee:
        carregarCafes();
        break;
      case ItemType.nation:
        carregarNacoes();
        break;
      default:
        break;
    }
  }

  void carregarCafes() {
    var coffeesUri = Uri(
      scheme: 'https',
      host: 'random-data-api.com',
      path: 'api/coffee/random_coffee',
      queryParameters: {'size': '10'},
    );

    loadData(coffeesUri, ItemType.coffee, ["blend_name", "origin", "variety"]);
  }

  void carregarNacoes() {
    var nationsUri = Uri(
      scheme: 'https',
      host: 'random-data-api.com',
      path: 'api/nation/random_nation',
      queryParameters: {'size': '10'},
    );

    loadData(
      nationsUri,
      ItemType.nation,
      ["nationality", "capital", "language", "national_sport"],
    );
  }

  void carregarCervejas() {
    var beersUri = Uri(
      scheme: 'https',
      host: 'random-data-api.com',
      path: 'api/beer/random_beer',
      queryParameters: {'size': '10'},
    );

    loadData(beersUri, ItemType.beer, ["name", "style", "ibu"]);
  }
}

final dataService = DataService();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final functionsMap = {
    ItemType.beer: dataService.carregarCervejas,
    ItemType.coffee: dataService.carregarCafes,
    ItemType.nation: dataService.carregarNacoes
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.red),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text("Infinite Scroll")),
        body: ValueListenableBuilder(
          valueListenable: dataService.tableStateNotifier,
          builder: (_, value, __) {
            switch (value['status']) {
              case TableStatus.idle:
                return Center(child: Text("Toque em um item, abaixo..."));
              case TableStatus.loading:
                return Center(child: CircularProgressIndicator());
              case TableStatus.ready:
                return ListWidget(
                  jsonObjects: value['dataObjects'],
                  propertyNames: value['propertyNames'],
                  displayedItemCount: value['dataObjects'].length,
                  scrollEndedCallback: functionsMap[value['itemType']],
                );
              case TableStatus.error:
                return Text("Lascou");
            }
            return Text("...");
          },
        ),
        bottomNavigationBar:
            NewNavBar(itemSelectedCallback: dataService.carregar),
      ),
    );
  }
}

class NewNavBar extends HookWidget {
  final _itemSelectedCallback;

  NewNavBar({itemSelectedCallback})
      : _itemSelectedCallback = itemSelectedCallback ?? (int) {}

  @override
  Widget build(BuildContext context) {
    var state = useState(1);
    return BottomNavigationBar(
      onTap: (index) {
        state.value = index;
        _itemSelectedCallback(ItemType.values[index]);
      },
      currentIndex: state.value,
      items: const [
        BottomNavigationBarItem(
          label: "Cervejas",
          icon: Icon(Icons.coffee_outlined),
        ),
        BottomNavigationBarItem(
          label: "Cafés",
          icon: Icon(Icons.local_drink_outlined),
        ),
        BottomNavigationBarItem(
          label: "Nações",
          icon: Icon(Icons.flag_outlined),
        ),
      ],
    );
  }
}

class ListWidget extends HookWidget {
  final dynamic _scrollEndedCallback;
  final List jsonObjects;
  final List<String> propertyNames;
  final int displayedItemCount;

  ListWidget({
    this.jsonObjects = const [],
    this.propertyNames = const ["name", "style", "ibu"],
    this.displayedItemCount = 0,
    void Function()? scrollEndedCallback,
  }) : _scrollEndedCallback = scrollEndedCallback ?? false;

  @override
  Widget build(BuildContext context) {
    var controller = useScrollController();

    useEffect(() {
      controller.addListener(() {
        if (controller.position.pixels == controller.position.maxScrollExtent)
          print('end of scroll');
        if (_scrollEndedCallback is Function) _scrollEndedCallback();
      });
    }, [controller]);

    return Column(
      children: [
        Text('(ITENS EXIBIDOS): $displayedItemCount'),
        Expanded(
          child: ListView.separated(
            controller: controller,
            padding: EdgeInsets.all(10),
            separatorBuilder: (_, __) => Divider(
              height: 5,
              thickness: 2,
              indent: 10,
              endIndent: 10,
              color: Theme.of(context).primaryColor,
            ),
            itemCount: jsonObjects.length + 1,
            itemBuilder: (_, index) {
              if (index == jsonObjects.length)
                return Center(child: LinearProgressIndicator());

              var title = jsonObjects[index][propertyNames[0]];
              var content = propertyNames
                  .sublist(1)
                  .map((prop) => jsonObjects[index][prop])
                  .join(" - ");

              return Card(
                shadowColor: Theme.of(context).primaryColor,
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    //a primeira propriedade vai em negrito
                    Text(
                      "${title}\n",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    //as demais vão normais
                    Text(content),
                    SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}