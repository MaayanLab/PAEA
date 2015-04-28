FROM rocker/shiny

COPY . /srv/shiny-server/

RUN sed -i -- 's/location \//location \/PAEA/g' /etc/shiny-server/shiny-server.conf

RUN apt-get install -y libmysqlclient-dev

RUN R -e "install.packages(c('ggvis', 'data.table', 'tidyr','dplyr','stringi','rjson','RMySQL','httr'), repos='http://cran.rstudio.com/')"

RUN R -e "source('http://bioconductor.org/biocLite.R');biocLite('preprocessCore')"

