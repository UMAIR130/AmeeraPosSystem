import 'package:flutter/material.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("MyApp"),
    backgroundColor: Colors.blue,centerTitle: true,
    ),
      body: Column(children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.height * 0.3,
                color: Colors.blue,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  spacing: 15,
                  children: [
                  ElevatedButton(onPressed: (){}, child: Text("Button 1")),
                  ElevatedButton(onPressed: (){}, child: Text("Button 2")),
                  ElevatedButton(onPressed: (){}, child: Text("Button 1")),
                  ElevatedButton(onPressed: (){}, child: Text("Button 1")),
                ],),
              ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                height: MediaQuery.of(context).size.height * 0.3
                ,color: Colors.amber,),
            ),
          ],
        ),
        Container(
            color: Colors.cyanAccent,

            width: double.infinity,
            child: Text("UMAIR iMTIAZ"))
      ],),
    );
  }
}
