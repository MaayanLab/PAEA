FROM rocker/shiny

COPY . /srv/shiny-server/

COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
# COPY shiny-server.conf /etc/init/shiny-server.conf

# RUN sed -i -- 's/location \//location \/PAEA/g' /etc/shiny-server/shiny-server.conf

RUN apt-get update

RUN apt-get install -y libmysqlclient-dev \
	libssl-dev \
	libxml2-dev 

RUN R -e "install.packages('devtools')"

RUN R -e "devtools::install_github('s-u/background')"

# RUN R -e "install.packages('Rcpp')"
RUN R -e "install.packages('https://cran.r-project.org/src/contrib/Archive/Rcpp/Rcpp_0.12.2.tar.gz', repos=NULL, type='source')"

RUN R -e "install.packages('https://cran.r-project.org/src/contrib/Archive/dplyr/dplyr_0.4.3.tar.gz', repos=NULL, type='source')"

RUN R -e "install.packages(c('ggvis', 'data.table', 'tidyr','stringi','rjson','RMySQL','httr'), repos='http://cran.rstudio.com/')"

RUN R -e "install.packages('dtplyr')"

RUN R -e "devtools::install_github('rstudio/pool')"

RUN R -e "source('http://bioconductor.org/biocLite.R');biocLite('preprocessCore')"

EXPOSE 3838
