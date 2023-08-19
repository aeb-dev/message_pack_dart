<p>
  <a title="Pub" href="https://pub.dev/packages/message_pack" ><img src="https://img.shields.io/pub/v/message_pack.svg?style=popout" /></a>
</p>

## Using with objects

```dart
class MyClass with Message {
  late int id;
  late String name;
  late DateTime time;

  @override
  List get messagePackFields => [id, name, time];

  MyClass();

  MyClass.fromMessagePack(List<dynamic> items) {
    id = items[0];
    name = items[1];
    time = items[2];
  }
}
```

To serialize an object to Message Pack format:
```dart
MyClass mc = MyClass()
  ..id = 1
  ..name = "aeb"
  ..time = DateTime.now();
Uint8List data = mc.toMessagePack();
```

To deserialize an object from Message Pack format:
```dart
Uint8List data = ... data from somewhere;
MyClass mc = fromMessagePack(data, MyClass.fromMessagePack);
```

## Manually writing
```dart
MessagePackWriter writer = MessagePackWriter();
writer.writeString("Hello");
Uint8List data = writer.takeBytes();
```

## Manually reading
```dart
Uint8List data = ... data from somewhere;
MessagePackReader reader = MessagePackReader.fromTypedData(data); // there are other alternatives
String sValue = reader.readString();
int iValue = reader.readInt();
```