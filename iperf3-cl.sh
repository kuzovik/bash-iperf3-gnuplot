#!/bin/bash

RHOST="ping.online.net"     # Default host
RPORT="5207"                # Default port for this host
PARAL="4"                   # Parallel streams
REVER="1"                   # 1=test receive, else=test transfer
HSECS="60"                  # How many seconds run test
ISECS="1"                   # Interval in seconds for write statistic
METER="m"                   # m=Mbit/sec

if [ "${REVER}" == "1" ] ; then FREAD="RX"; REVER="-R"; else FREAD="TX"; REVER=""; fi
FDATA="`echo ${0}|sed s/'\.sh'/'\.dat'/g`"
DDIR="/var/tmp/iperf3_tests"

wait(){
    echo -n "Press ENTER for continue..."; read k
}

rmFL(){ 
    rm -f ${LFILE}.txt
}

psKL(){
    PSC=`ps x -A | grep "iperf3" | grep "c $1" | grep "p $2" | grep -v grep | awk '{ print $1 }'`
    if [ "${PSC}" != "" ] ; then sudo kill -9 ${PSC} 1>/dev/null 2>/dev/null; fi
}

plotchart(){
echo "Please wait... plotting chart..."

# Format file to plot:
# UnixTime  VAL_P1  VAL_P2  VAL_P3  VAL_P4  VAL_SM

gnuplot << EOP
set terminal pngcairo size 1000,500 font 'Verdana,10' 
set termoption enhanced
set output "$LFILE.png"
set multiplot
set grid
set xdata time
set timefmt "%s"
set format x "%H:%M:%S"
set xtics  5 font 'Verdana,8' rotate by 90 mirror offset 0,-3.1
set ytics 10 font 'Verdana,8' tc rgb "blue"(10,20,30,40,50,60,70,80,90,100)
set yrange  [0:100]
set x2range [0:100]
set y2range [0:100]
set lmargin 8
set bmargin 8
set xlabel "Время (ЧЧ:ММ:СС)" font 'Verdana:Bold,10' offset 9.8,-2.2 tc rgb "black"
set ylabel "Мбит/сек"         font 'Verdana:Bold,10' offset 1.5, 1   tc rgb "blue"
set title  "Тест для $RHOST:$RPORT $FREAD сделан $GDATE" font 'Verdana:Bold,12' tc rgb "dark-red"
#
set label 2 "Поток 1"   at graph 0,0 left front font ",10" tc lt 2 offset -1,-6
set label 3 "Поток 2"   at graph 0,0 left front font ",10" tc lt 3 offset  7,-6
set label 4 "Поток 3"   at graph 0,0 left front font ",10" tc lt 4 offset 15,-6
set label 5 "Поток 4"   at graph 0,0 left front font ",10" tc lt 5 offset 23,-6
#
b1=0; b2=0; b3=0; bx=0; mn=100; mx=0; sm=0; av=0; cn=0;
avr6(x) = (cn=cn+1, sm=sm+x, av=sm/cn)
max6(x) = (mx=(mx<x)?x:mx)
min6(x) = (mn=(mn>x)?x:mn)
shf6(x) = (b3=b2, b2=b1, b1=x, bx=(bx<3)?(bx+1):3)
fnc6(x) = (min6(x), max6(x), avr6(x), shf6(x), (b1+b2+b3)/bx)
#
plot \
     "$LFILE.dat" using (timecolumn(1)+2*60*60):2 notitle with lines  lc 2 lw 2,\
     "$LFILE.dat" using (timecolumn(1)+2*60*60):3 notitle with lines  lc 3 lw 2,\
     "$LFILE.dat" using (timecolumn(1)+2*60*60):4 notitle with lines  lc 4 lw 2,\
     "$LFILE.dat" using (timecolumn(1)+2*60*60):5 notitle with lines  lc 5 lw 2,\
     "$LFILE.dat" using (timecolumn(1)+2*60*60):6 notitle with points pt 1 lc rgb "orange",\
     "$LFILE.dat" using (timecolumn(1)+2*60*60):(fnc6(\$6)) smooth bezier with lines notitle lc 1 lw 5     
#
set label 1 sprintf("Суммарный:  МИН=%2d  МАКС=%2d  СРЕД=%2d (Мбит/сек)",mn,mx,av) at graph 0,0 left front font ":Bold,10" tc lt 1 offset -1,-4.8
# verticale
# set arrow 1 from second 80,1 to second 80,99 nohead front lc rgb "black"  lw 1
# horizontale
  set arrow 2 from second 1,av to second 99,av nohead front lc rgb "yellow" lw 1
refresh
#
EOP
mirage $LFILE.png 1>/dev/null 2>/dev/null &
}



if [ "$1" == "test" ] ; then
    LFILE="testgraph"
    GDATE=`date "+%Y-%m-%d %H:%M:%S"`
    plotchart
    exit
fi


if [ -f ${FDATA} ] ; then
   while [ 1 -eq 1 ] ; do
   clear;a=0;b=0;f=0;
   while read LINE ; do
      a=`expr $a + 1`
      CStr[$a]="$LINE"
      FChar=`echo ${LINE}| awk '{ $1=substr($1,0,1); print $1 }'`
      if [ "$FChar" == "#" ] ; then continue; fi
      b=`expr $b + 1`
      if [ "$FChar" == "=" ] ; then LINE=`echo "${LINE}" | sed s/=//g`; f=$b; fi
      HostNAME[$b]=`echo ${LINE} | awk '{ print $1 }'`
      HostCODE[$b]=`echo ${LINE} | awk '{ print $2 }'`
      HostBAUD[$b]=`echo ${LINE} | awk '{ print $3 }'`
      HostVERS[$b]=`echo ${LINE} | awk '{ print $4 }'`
      HostPROT[$b]=`echo ${LINE} | awk '{ print $5 }'`
      HostPORT[$b]=`echo ${LINE} | awk '{ print $6 }'`
      #echo "HNAME=${HostNAME[$a]}  HCODE=${HostCODE[$a]}  HBAUD=${HostBAUD[$a]}  HVERS=${HostVERS[$a]}  HPROT=${HostPROT[$a]} HPORT=${HostPORT[$a]}"
      echo "$b. ${LINE}"
      if [  $f -eq $b ] ; then RHOST=${HostNAME[$f]}; RPORT=${HostPORT[$f]}; fi
   done < ${FDATA}
   echo; echo "Current: ${f}. ${RHOST}:${RPORT}"; echo;
   echo -n "For exit Ctrl-C or Enter your number and press ENTER: "; read k; [ "$k" == "" ] && k=$f
   VALI=`echo "$k" | awk '{ $1=strtonum($1); print $1 }'`
   if [ $VALI -lt 1 ] || [ $VALI -gt $b ] ; then 
      echo "ERROR: Bad choice. Enter number from 1 to $b and press ENTER. Try again..."
      sleep 2
   else
      RHOST=${HostNAME[$VALI]}; RPORT=`echo ${HostPORT[$VALI]}|sed s/'-'/' '/g|awk '{ print $1 }'`
      echo "Choice host: $RHOST:$RPORT"
      echo -n "For continue enter 'y' and press ENTER or enter any for try again: "; read k
      if [ "$k" == "" ] || [ "$k" == "y" ] || [ "$k" == 'Y' ] ; then break; fi
   fi
   done
else
   echo "File [${FDATA}] not found."
fi


CDATE=`date "+%Y%m%d%H%M%S"`
GDATE=`date "+%Y-%m-%d %H:%M:%S"`
if [ ! -d ${DDIR} ] ; then mkdir -p ${DDIR} 2>/dev/null; chmod 777 ${DDIR}; fi
LFILE="${DDIR}/${CDATE}_IPERF_${RHOST}_${RPORT}_${FREAD}"


echo;
echo "Test run for: $RHOST:$RPORT $FREAD"
echo "Test length : $HSECS sec with stat interval 5 sec"
echo "Data file   : $LFILE.txt"


gksu -w "iperf3 -c ${RHOST} -p ${RPORT} -t ${HSECS} -i ${ISECS} -P ${PARAL} -f ${METER} ${REVER} --logfile ${LFILE}.txt" &
OSTR=""
HOWO=0
b=0
while [ 1 -eq 1 ]
do
    HOWL=`cat ${LFILE}.txt 2>/dev/null|wc -l`
    HOWT=`expr $HOWL - $HOWO`
    if [ ${HOWT} -gt 0 ] ; then
       tail -${HOWT} ${LFILE}.txt
       HOWO=${HOWL}
       b=0
    fi
    # if not answer more 5 tics
    b=`expr $b + 1`; [ $b -gt 5 ] && break;
    sleep 0.4
done


FSZ=`stat -c%s "${LFILE}.txt"`
if [ $FSZ -lt 100 ] ; then echo "ERROR: log-file size [${FSZ}]."; psKL ${RHOST} ${RPORT} 1>/dev/null 2>/dev/null; exit; fi

ERRR=`cat ${LFILE}.txt|grep -i error|wc -l`
if [ $ERRR -gt 0 ] ; then psKL "${RHOST}" "${RPORT}" 1>/dev/null 2>/dev/null; exit; fi

for((a=1; a<=${PARAL}; a++)){ APAR[$a]=0; AVAL[$a]=0; }
APAR[5]=99;CSEC=`date +%s`;a=0;b=0;


echo "Please wait... parse log-file..."

# parse log-file
while read LINE
do
    if [ `echo "${LINE}" | grep "\["   | wc -l` -eq 0 ] ; then continue; fi
    if [ `echo "${LINE}" | grep "ID\]" | wc -l` -gt 0 ] ; then continue; fi
    if [ `echo "${LINE}" | grep "send" | wc -l` -gt 0 ] ; then continue; fi
    ANUM=`echo  ${LINE}  | cut -d']' -f1 | cut -d'[' -f2`
    if [ "$ANUM" == "SUM" ] ; then ANUM=99; fi
    if [ $a -lt `expr $PARAL` ] ; then
         a=`expr $a + 1`
         APAR[$a]=$ANUM
         continue;
    fi
    if [ $b -lt `expr $PARAL + 1` ] ; then
         b=`expr $b + 1`
         for((c=1; c<=${PARAL}+1; c++)){
            if [ "${APAR[$c]}" == "${ANUM}" ] ; then
               AVAL[$b]=`echo "$LINE" | awk -F"sec" '{ print $2 }' | awk '{ print $3 }'`
#              echo "AVAL[$b]=${AVAL[$b]}"
               break
            fi
         }
    fi
#   echo "${ANUM}::${LINE}"
    if [ $ANUM -eq 99 ] ; then
         CSEC=`expr $CSEC + $ISECS`
         echo "${CSEC} ${AVAL[1]} ${AVAL[2]} ${AVAL[3]} ${AVAL[4]} ${AVAL[5]}" >> ${LFILE}.dat
         b=0
    fi
done < ${LFILE}.txt

psKL "${RHOST}" "${RPORT}"

plotchart

#rmFL
#wait
