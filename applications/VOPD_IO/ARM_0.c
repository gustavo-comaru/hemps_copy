#include <api.h>
#include <stdlib.h>

int main()
{

Message msg,msgIO;
int j;

	Echo("##### INICIO 1 DA VOPD");

	for(j=0;j<128;j++) msg.msg[j]=j;

	/*Comm Peripheral*/
	msgIO.length = 128;
	IOReceive(&msgIO,IO_PERIPHERAL3);

	msg.length=128;
	Send(&msg,IDCT2_0);
	Echo("Mandou IDCT2_0");

	exit();

}
