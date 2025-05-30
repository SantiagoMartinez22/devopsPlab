from todor import create_app
import os
import pytest
from todor import create_app, db
from todor.models import User, Todo

@pytest.fixture
def app():
    """Crear aplicación para pruebas"""
    # Configurar variables de entorno para pruebas
    os.environ['SECRET_KEY'] = 'test_key'
    os.environ['DATABASE_URL'] = 'sqlite:///:memory:'
    
    app = create_app()
    app.config['TESTING'] = True
    
    # Crear todas las tablas en la base de datos
    with app.app_context():
        db.create_all()
    
    yield app
    
    # Limpiar después de las pruebas
    with app.app_context():
        db.drop_all()

@pytest.fixture
def client(app):
    """Cliente de pruebas"""
    return app.test_client()

@pytest.fixture
def runner(app):
    """Runner de comandos de prueba"""
    return app.test_cli_runner()

def test_app_creation(app):
    """Prueba que la aplicación se crea correctamente"""
    assert app is not None
    assert app.config["TESTING"] is True

def test_home_page(client):
    """Prueba básica de que la ruta principal funciona"""
    response = client.get("/")
    assert response.status_code == 200
    assert b"Bienvenido" in response.data

def test_404_behavior(client):
    """Prueba que las rutas inexistentes devuelven 404"""
    response = client.get("/ruta/que/no/existe")
    assert response.status_code == 404

def test_register_user(client, app):
    """Prueba el registro de usuarios"""
    response = client.post('/auth/register', data={
        'username': 'testuser',
        'password': 'testpass'
    }, follow_redirects=True)
    assert response.status_code == 200
    
    with app.app_context():
        user = User.query.filter_by(username='testuser').first()
        assert user is not None
        assert user.username == 'testuser'

def test_login_logout(client, app):
    """Prueba el login y logout de usuarios"""
    # Registrar usuario
    client.post('/auth/register', data={
        'username': 'testuser',
        'password': 'testpass'
    })
    
    # Login
    response = client.post('/auth/login', data={
        'username': 'testuser',
        'password': 'testpass'
    }, follow_redirects=True)
    assert response.status_code == 200
    assert b"Tareas" in response.data
    
    # Logout
    response = client.get('/auth/logout', follow_redirects=True)
    assert response.status_code == 200
    assert b"Iniciar sesi" in response.data  # "Iniciar sesión" en español

def test_create_todo(client, app):
    """Prueba la creación de tareas"""
    # Registrar y login
    client.post('/auth/register', data={
        'username': 'testuser',
        'password': 'testpass'
    })
    client.post('/auth/login', data={
        'username': 'testuser',
        'password': 'testpass'
    })
    
    # Crear tarea
    response = client.post('/todo/create', data={
        'title': 'Test Todo',
        'desc': 'Test Description'
    }, follow_redirects=True)
    assert response.status_code == 200
    assert b"Test Todo" in response.data
    
    with app.app_context():
        todo = Todo.query.filter_by(title='Test Todo').first()
        assert todo is not None
        assert todo.desc == 'Test Description'