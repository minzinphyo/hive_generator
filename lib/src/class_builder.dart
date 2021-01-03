import 'dart:developer';
import 'dart:typed_data';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:hive/hive.dart';
import 'package:hive_generator/src/builder.dart';
import 'package:hive_generator/src/helper.dart';
import 'package:source_gen/source_gen.dart';
import 'package:built_collection/built_collection.dart';

class ClassBuilder extends Builder {
  var hiveListChecker = const TypeChecker.fromRuntime(HiveList);
  // var listChecker = const TypeChecker.fromRuntime(List);
  // var mapChecker = const TypeChecker.fromRuntime(Map);
  // var setChecker = const TypeChecker.fromRuntime(Set);
  // var iterableChecker = const TypeChecker.fromRuntime(Iterable);
  var builtListChecker = const TypeChecker.fromRuntime(BuiltList);
  var builtMapChecker = const TypeChecker.fromRuntime(BuiltMap);
  var builtSetChecker = const TypeChecker.fromRuntime(BuiltSet);
  var iterableChecker = const TypeChecker.fromRuntime(Iterable);
  var uint8ListChecker = const TypeChecker.fromRuntime(Uint8List);

  ClassBuilder(
      ClassElement cls, List<AdapterField> getters, List<AdapterField> setters)
      : super(cls, getters, setters);

  @override
  String buildRead() {
    var code = StringBuffer();

    code.writeln('''
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return (${cls.name}Builder()
    ''');

    var fields = getters;
    for (var field in fields) {
      // check(!isMapOrIterable(field.type),
      //     'Please use BuiltList, BuiltSet or BuiltMap');

      final type = field.type;
      final index = field.index;

      code.writeln('..${field.name} = ${_cast(type, 'fields[$index]')}');
    }

    code.writeln(').build();');

    return code.toString();
  }

  String _cast(DartType type, String variable) {
    if (hiveListChecker.isExactlyType(type)) {
      return '($variable as HiveList)?.castHiveList()';
    } else if (iterableChecker.isAssignableFromType(type) &&
        !isUint8List(type)) {
      return '${_castIterable(type, variable)}';
    } else if (builtMapChecker.isExactlyType(type)) {
      return '${_castMap(type, variable)}';
    } else {
      return '$variable as ${type.getDisplayString()}';
    }
  }

  bool isMapOrIterable(DartType type) {
    return builtListChecker.isExactlyType(type) ||
        hiveListChecker.isExactlyType(type) ||
        builtSetChecker.isExactlyType(type) ||
        iterableChecker.isExactlyType(type) ||
        builtMapChecker.isExactlyType(type);
  }

  bool isUint8List(DartType type) {
    return uint8ListChecker.isExactlyType(type);
  }

  String _castIterable(DartType type, String variable) {
    var paramType = type as ParameterizedType;
    var arg = paramType.typeArguments[0];
    print('$arg ${isMapOrIterable(arg)} and ${isUint8List(type)}');
    if (isMapOrIterable(type) && !isUint8List(arg)) {
      var cast = '';
      if (builtListChecker.isExactlyType(type)) {
        cast = 'ListBuilder<$arg>($variable as List)';
      } else if (builtSetChecker.isExactlyType(type)) {
        cast = 'SetBuilder<$arg>($variable as Set)';
      }
      // return '?.map((dynamic e)=> ${_cast(arg, 'e')})$cast';
      return cast;
    } else {
      return '($variable as List)?.cast<${arg.getDisplayString()}>()';
    }
  }

  String _castMap(DartType type, String variable) {
    var paramType = type as ParameterizedType;
    var arg1 = paramType.typeArguments[0];
    var arg2 = paramType.typeArguments[1];
    if (isMapOrIterable(arg1) || isMapOrIterable(arg2)) {
      // return '?.map((dynamic k, dynamic v)=>'
      //     'MapEntry(${_cast(arg1, 'k')},${_cast(arg2, 'v')}))';
      return 'MapBuilder<$arg1, $arg2>($variable as Map)';
    } else {
      return '''($variable as Map)?
      .cast<${arg1.getDisplayString()}, ${arg2.getDisplayString()}>()
      ''';
    }
  }

  @override
  String buildWrite() {
    var code = StringBuffer();
    code.writeln('writer');
    code.writeln('..writeByte(${getters.length})');
    for (var field in getters) {
      var value = _convertIterable(field.type, 'obj.${field.name}');
      code.writeln('''
      ..writeByte(${field.index})
      ..write($value)''');
    }
    code.writeln(';');

    return code.toString();
  }

  String _convertIterable(DartType type, String accessor) {
    if (builtSetChecker.isExactlyType(type) ||
        iterableChecker.isExactlyType(type)) {
      return '$accessor?.toList()';
    } else {
      return accessor;
    }
  }
}
