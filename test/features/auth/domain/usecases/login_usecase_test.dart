import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studyhub/domain/entities/user_entity.dart';
import 'package:studyhub/domain/repositories/auth_repository.dart';
import 'package:studyhub/domain/usecases/auth/login_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late LoginUseCase usecase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    usecase = LoginUseCase(mockRepository);
  });

  final tUser = UserEntity(
    id: '1',
    name: 'Admin',
    email: 'admin@studyhub.com',
    createdAt: DateTime(2023, 1, 1),
  );

  test('nên trả về UserEntity khi đăng nhập thành công', () async {
    // Arrange
    when(() => mockRepository.login(
        emailOrPhone: any(named: 'emailOrPhone'),
        password: any(named: 'password'))).thenAnswer((_) async => tUser);

    // Act
    final result =
        await usecase(emailOrPhone: "admin@studyhub.com", password: "123456");

    // Assert
    expect(result, tUser);
  });
}
