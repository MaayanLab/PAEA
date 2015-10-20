FROM rocker/shiny

COPY . /srv/shiny-server/

RUN sed -i -- 's/location \//location \/PAEA/g' /etc/shiny-server/shiny-server.conf

RUN apt-get update

RUN apt-get install -y libmysqlclient-dev \
	libssl-dev \
	libxml2-dev 

RUN R -e "install.packages('devtools')"

RUN R -e "devtools::install_github('s-u/background')"

RUN R -e "install.packages('Rcpp')"

RUN R -e "install.packages(c('dplyr', 'ggvis', 'data.table', 'tidyr','stringi','rjson','RMySQL','httr'), repos='http://cran.rstudio.com/')"

RUN R -e "source('http://bioconductor.org/biocLite.R');biocLite('preprocessCore')"

