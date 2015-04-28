# ORMs for the database to store PAEA lists
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import ForeignKey, Column, Integer, String, Table, Float, Text, DATETIME
from sqlalchemy.orm import backref, relationship
from sqlalchemy.orm import scoped_session, sessionmaker

from datetime import datetime

engine = create_engine('mysql://root:@localhost/paea')
Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
# session = scoped_session(Session)
session = Session()

## ORMs of the database
Base = declarative_base()

class Association(Base):
    __tablename__ = 'association'
    list_id = Column(Integer, ForeignKey('lists.id'), primary_key=True)
    gene_id = Column(Integer, ForeignKey('genes.id'), primary_key=True)
    coef = Column(Float)
    gene = relationship("Gene")


class List(Base):
	__tablename__ = 'lists'

	id = Column(Integer, primary_key=True)
	hash = Column(String(32), unique=True)
	desc = Column(Text)
	time = Column(DATETIME)

	genes = relationship('Association')

	def __repr__(self):
		return "<List(hash='%s', desc='%s')>" % (self.hash, self.desc)


class Gene(Base):
	"""docstring for Gene"""
	__tablename__ = 'genes'

	id = Column(Integer, primary_key=True)
	name = Column(String(32), unique=True)

	def __repr__(self):
		return "<Gene(name='%s')>" % self.name

Base.metadata.create_all(engine)

## functions to add and retrieve objects 
def get_or_create(session, model, **kwargs):
	# init a instance if not exists
	# http://stackoverflow.com/questions/2546207/does-sqlalchemy-have-an-equivalent-of-djangos-get-or-create
	instance = session.query(model).filter_by(**kwargs).first()
	if instance:
		return instance
	else:
		instance = model(**kwargs)
		session.add(instance)
		session.commit()
		return instance	

def _init_list(hash_str, desc=None):
	# init a List instance
	now = datetime.now()
	l = List(hash=hash_str, desc=desc, time=now)
	return l

def add_associations(hash_str, genenames, coefs, session, desc=None):
	# add associations (a gene list with all the genes and coefs from post request)
	# into the database
	# l = _init_list(hash_str, desc=desc)
	l = get_or_create(session, List, hash=hash_str, desc=desc)
	for coef, genename in zip(coefs, genenames):
		a = Association(coef=coef)
		a.gene = get_or_create(session, Gene, name=genename)
		l.genes.append(a)
	try:
		session.add(l)
		session.commit()
	except Exception as e:
		session.rollback()
		print e
		pass
	return

def get_associations(hash_str, session):
	# get a gene list from the database
	query = session.query(List).filter(List.hash == hash_str)
	l = query.first()
	genenames = []
	coefs = []
	for assoc in l.genes:
		coefs.append(assoc.coef)
		genenames.append(assoc.gene.name)
	return genenames, coefs, l.desc

