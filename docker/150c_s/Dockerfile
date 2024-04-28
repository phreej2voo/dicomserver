# ******************************************************************
# 
# barebone conquest with sqlite database
# 
# ******************************************************************

FROM debian
RUN apt update
RUN apt install -y wget zip g++ make lua5.1 liblua5.1-0 lua-socket p7zip-full sudo
RUN apt install -y gettext-base
RUN ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so.0 /usr/lib/x86_64-linux-gnu/liblua5.1.so

RUN wget http://natura-ingenium.nl/dicomserver/dicomserver150d.zip
RUN mkdir conquest; cd conquest; unzip ../dicomserver150d.zip
RUN cd conquest; chmod +x linux/updatelinux; ./linux/updatelinux
RUN cd conquest; chmod +x linux/regen; linux/regen

RUN echo "#!/bin/bash" > startConquest.sh; \
	echo "cd /conquest" >> startConquest.sh; \
	echo "./dgate -v" >> startConquest.sh; \
	chmod +x startConquest.sh

RUN rm dicomserver150d.zip
RUN rm -R conquest/src
RUN rm -R conquest/install32
RUN rm -R conquest/install64
RUN rm -R conquest/webserver
RUN apt remove -y lua5.1 liblua5.1-0 lua-socket gettext-base g++ wget make

COPY * conquest/
CMD ["/startConquest.sh"]
