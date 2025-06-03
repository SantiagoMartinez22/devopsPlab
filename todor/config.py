import os

class Config:
    DEBUG = False
    SECRET_KEY = os.environ['SECRET_KEY']
    SQLALCHEMY_DATABASE_URI = os.environ['DATABASE_URL']
    SQLALCHEMY_TRACK_MODIFICATIONS = False

# Seleccionar la configuración basada en el ambiente
config = {
    'development': Config,
    'production': Config,
    'default': Config
} 