FROM rocker/shiny
COPY . /home
WORKDIR /home

RUN apt-get update
RUN apt-get install -y python-pip python-rpy2
	
RUN pip install Flask

RUN apt-get install -y libmysqlclient-dev \
	libssl-dev \
	libxml2-dev 

RUN R -e "install.packages('Rcpp')"

RUN R -e "install.packages(c('dplyr', 'data.table','rjson','RMySQL','httr'), repos='http://cran.rstudio.com/')"

EXPOSE 5000
CMD python app.py 5000 0.0.0.0
