from todor import create_app
import os

app = create_app()

if __name__ == '__main__':
    # Configurar host y puerto para producción
    host = os.environ.get('FLASK_HOST', '0.0.0.0')
    port = int(os.environ.get('FLASK_PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    
    app.run(host=host, port=port, debug=debug)