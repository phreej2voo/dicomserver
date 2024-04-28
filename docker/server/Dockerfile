# ******************************************************************
# 
# barebone prebuilt conquest with sqlite database
# 
# ******************************************************************

FROM debian
RUN apt -y update && apt -y install wget zip lua5.1 liblua5.1-0 lua-socket p7zip-full
RUN ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so.0 /usr/lib/x86_64-linux-gnu/liblua5.1.so
RUN wget http://natura-ingenium.nl/dicomserver/dicomserver150c_prerelease3.zip
RUN mkdir conquest; cd conquest; unzip ../dicomserver150c_prerelease3.zip
RUN apt remove -y wget zip

RUN cd conquest; cp linux/conf/dicom.ini.sqlite ./dicom.ini
RUN cd conquest; cp linux/conf/dicom.sql.sqlite ./dicom.sql
RUN cd conquest; cp linux/acrnema.map .
RUN cd conquest; sed -i 's+${CONQUEST}+/conquest+g'  dicom.ini
RUN cd conquest; mkdir data/dbase
RUN cd conquest; cp linux/dgate .; chmod 777 dgate

RUN echo "#!/bin/bash" > startConquest.sh; \
	echo "cd /conquest" >> startConquest.sh; \
	echo "./dgate -v" >> startConquest.sh; \
	chmod +x startConquest.sh
	
COPY * conquest/

RUN rm dicomserver150c_prerelease3.zip
RUN rm -R conquest/src
RUN rm -R conquest/install32
RUN rm -R conquest/install64
RUN rm -R conquest/webserver
RUN rm -R conquest/contributions
RUN rm -r conquest/clibs/*
RUN rm conquest/linux/dgate

RUN cd conquest; ./dgate -v -r

