#if ${ISXEVE(exists)}
#else
	#error ComBot requires ISXEVE to be loaded before running
#endif

#include core/obj_ComBot.iss

#include core/obj_Move.iss
#include core/obj_CommandQueue.iss



function atexit()
{

}

function main()
{
	echo "${Time} ComBot: Starting"

	declarevariable ComBot obj_ComBot script
	declarevariable Move obj_Move script
	declarevariable CommandQueue obj_CommandQueue script
	
	
	while TRUE
	{
		wait 10
	}
}
