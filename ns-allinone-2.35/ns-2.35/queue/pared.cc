/**
*Pared算法，基于Ared算法之上。
*/

#include <string.h>
#include "queue.h"
#include <iostream>
#include <fstream>
#include <math.h>
#include <cstdlib>
#include <time.h>
#include "random.h"
using namespace std;

class Pared;
class Pared : public Queue {
public :
	Pared();
	~Pared();
	void over();
	void totalpkt();
	void getAvg();
	int getLevel();
	void putQl();
	void putAvg();
	void putLp();
	void putTp();
	void putTd();
protected :
	virtual int command(int argc, const char*const* argv);
	virtual Packet *deque(void);
	virtual void enque(Packet *pkt);

	PacketQueue *q_ = new PacketQueue(); //包队列(缓冲区)s
	double  avg;//平均队列长度
	double  avgL;//上一次平均队列长度
	double wq;//预设的权值（0-1）
	int minth;//丢弃区间下限
	int maxth;//丢弃区间上限
	double pd;//丢弃概率
	double maxp;//最大丢弃概率
	double mintarget;//Ared的目标范围
	double maxtarget;//Ared的目标范围
	double alpha;
	double beta;
	double mytime; //用于统计记时
	double E1; //均值
	double D1; //方差
	int pktcnt_pers_lp; //每个时间间隔内入队包数，丢包率统计用
	int pktcnt_pers_tp; //每个时间间隔内入队包数，吞吐量统计用
	int pktcnt_pers_td; //每个时间间隔内入队包数，时延统计用
	int pktcnt_pers; //每个时间间隔内入队包数，计算等级用
	int pktcnt; //总包数
	int dpktcnt;//丢包数
	int opktcnt;//出队包数
	double timeDelay;//数据包时延
	int count; //统计个数
	ofstream fqlength1; //输出瞬时队列长度
	ofstream fqlength2; //输出瞬时队列长度 仅仅有数值
	ofstream favg1; //输出平均队列长度
	ofstream favg2; //输出平均队列长度 仅仅有数值
	ofstream flosspkt1; //输出平均丢包率
	ofstream flosspkt2; //输出平均丢包率 仅仅有数值
	ofstream fthroughput1; //输出平均吞吐量
	ofstream fthroughput2; //输出平均吞吐量 仅仅有数值
	ofstream ftimedelay1;//输出平均时延
	ofstream ftimedelay2;//输出平均时延 仅仅有数值
	double  pertime_;//统计时间间隔


};

//在OTCL里面注册我的Tque类
static class ParedClass : public TclClass {
public :
	ParedClass() : TclClass("Queue/Pared") {}
	TclObject *create(int argc, const char*const* argv) {
		return (new Pared());
	}
} class_pared;

Pared::Pared() {
	avgL = 0;
	avg = 0;
	wq = 0.002;
	minth = 5;
	maxth = 15;
	pd = 0;
	maxp = 0.1;
	mintarget = minth + 0.4*(maxth-minth);
	maxtarget = minth + 0.6*(maxth-minth);
	if(maxp/4 <= 0.01) {
		alpha = maxp/4;
	} else {
		alpha = 0.01;
	}
	beta = 0.9;
	mytime = 0;
	E1 = 2377.28180;
	D1 = 302.00101;
	pktcnt_pers_lp = 0;
	pktcnt_pers_tp = 0;
	pktcnt_pers_td = 0;
	pktcnt_pers = 0;
	dpktcnt = 0;
	opktcnt = 0;
	timeDelay = 0;
	count = 0;
	fqlength1.open("/home/yzr/common/mywork/pared_ql.txt",ios::out);
	fqlength2.open("/home/yzr/common/mywork/pared_ql_d.txt",ios::out);
	favg1.open("/home/yzr/common/mywork/pared_avg.txt",ios::out);
	favg2.open("/home/yzr/common/mywork/pared_avg_d.txt",ios::out);
	flosspkt1.open("/home/yzr/common/mywork/pared_lp.txt",ios::out);
	flosspkt2.open("/home/yzr/common/mywork/pared_lp_d.txt",ios::out);
	fthroughput1.open("/home/yzr/common/mywork/pared_tp.txt",ios::out);
	fthroughput2.open("/home/yzr/common/mywork/pared_tp_d.txt",ios::out);
	ftimedelay1.open("/home/yzr/common/mywork/pared_td.txt",ios::out);
	ftimedelay2.open("/home/yzr/common/mywork/pared_td_d.txt",ios::out);
	pertime_ = 1;
	bind("pertime_", &pertime_);

	//初始化随机数种子，已经验证没重复
	srand((unsigned int)time(NULL));
}
Pared::~Pared(){
	delete q_;
	fqlength1.close();
	fqlength2.close();
	favg1.close();
	favg2.close();
	flosspkt1.close();
	flosspkt2.close();
	fthroughput1.close();
	fthroughput2.close();
	ftimedelay1.close();
	ftimedelay2.close();
}

void Pared::enque(Packet *pkt) {
	pktcnt_pers_td++;
	pktcnt_pers_lp++;
	pktcnt_pers_tp++;
	pktcnt_pers++;
	double t = Scheduler::instance().clock();

	hdr_cmn *ch= hdr_cmn::access(pkt);
	// if(linkflag == 1){
	// 	cout << t-ch->ts_ <<endl;
	// }
	

	if(q_ ->length() >= 35) {
		drop(pkt);
		dpktcnt++;
	} else {
		//计算丢弃概率
		if(avg < minth) {
			pd = 0;
			//直接入队
			q_->enque(pkt);
			timeDelay += t-ch->ts_;
			pktcnt++;
			
		} else if(avg >= minth && avg < maxth) {
			pd = (double)(avg-minth)/(double)(maxth-minth)*maxp;
			//printf("%lf\n",pd);
			int a;
			a = rand()%100;
			//printf("%ld\n",a);
			if(a <= pd*100) {
				//丢弃
				drop(pkt);
				dpktcnt++;

			} else {
				//入队
				q_->enque(pkt);
				timeDelay += t-ch->ts_;

				pktcnt++;
				//printf("%ld\n",pktcnt);
			}

		}else if(avg >= maxth) {
			pd = 1;
			//直接丢弃
			drop(pkt);
			dpktcnt++;
			//printf("%ld\n",dpktcnt);
		}
	}

}

Packet *Pared::deque() {
	opktcnt++;
	return (q_->deque());
}

void Pared::getAvg() {
	avg = (1-wq)*avgL+wq*q_ ->length();
	avgL = avg;
	//printf("%lf\n",avg);
	int level = getLevel();
	if(avg > maxtarget && maxp < 0.5) {
		if(level >= 5){
			alpha = 0.25*maxp*0.125*(level-1);
		}else{
			if(maxp/4 <= 0.01) {
				alpha = maxp/4;
			} else {
				alpha = 0.01;
			}
		}
		maxp = maxp + alpha;
	} else if (avg < mintarget && maxp > 0.01) {
		if(level < 5){
			beta = 0.83+(0.07*0.2*(level-1));
		}else{
			beta = 0.9;
		}
		maxp = maxp * beta;
	}
}

int Pared::getLevel() {
	int level = 0;
	if(pktcnt_pers < E1-3*D1) {
		level = 1;
	}else if (pktcnt_pers >= E1-3*D1 && pktcnt_pers < E1-2*D1) {
		level = 2;
	}else if (pktcnt_pers >= E1-2*D1 && pktcnt_pers < E1-D1) {
		level = 3;
	}else if (pktcnt_pers >= E1-D1 && pktcnt_pers < E1) {
		level = 4;
	}else if (pktcnt_pers >= E1 && pktcnt_pers < E1+D1) {
		level = 5;
	}else if (pktcnt_pers >= E1+D1 && pktcnt_pers < E1+2*D1) {
		level = 6;
	}else if (pktcnt_pers >= E1+2*D1 && pktcnt_pers < E1+3*D1) {
		level = 7;
	}else if (pktcnt_pers >= E1+3*D1) {
		level = 8;
	}
	return level;
}

void Pared::totalpkt() {
	//if(linkflag ==1) {
	count++;
		cout << count << "Pared的总包数=" <<pktcnt << endl;
		pktcnt = 0;
	//}
}

void Pared::putQl() {
	double t = Scheduler::instance().clock();
	fqlength1 << t << " " <<q_ ->length() << endl;
	fqlength2 <<q_ ->length() << endl;
}
void Pared::putAvg() {
	double t = Scheduler::instance().clock();
	favg1 << t << " " << avg << endl;
	favg2 <<avg << endl;
}
void Pared::putLp() {
	double t = Scheduler::instance().clock();
	double data;
	if(pktcnt_pers_lp != 0) {
		data = double(dpktcnt)/pktcnt_pers_lp;
	}else{
		data = 0;
	}
	flosspkt1 << t << " " << data << endl;
	flosspkt2 << data << endl;
	dpktcnt = 0;
	pktcnt_pers_lp = 0;
}
void Pared::putTp() {
	double t = Scheduler::instance().clock();
	double data;
	if(pktcnt_pers_tp != 0) {
		data = double(opktcnt)/pertime_;
	}else{
		data = 0;
	}
	fthroughput1 << t << " " << data << endl;
	fthroughput2 << data << endl;
	opktcnt = 0;
	pktcnt_pers_tp = 0;
}
void Pared::putTd() {
	double t = Scheduler::instance().clock();
	double data;
	if(pktcnt_pers_td != 0) {
		data = timeDelay/pktcnt_pers_td;

	}else{
		data = 0;
	}
	ftimedelay1 << t << " " << data << endl;
	ftimedelay2<< data << endl;
	timeDelay = 0;
	pktcnt_pers_td = 0;
}

int Pared::command(int argc, const char*const* argv)
{
	if (argc==2) {
		if (strcmp(argv[1], "totalpkt") == 0) {
			totalpkt();
			return (TCL_OK);
		} else if (strcmp(argv[1], "getAvg") == 0) {
			getAvg();
			return (TCL_OK);
		} else if (strcmp(argv[1], "output") == 0) {
			putQl();
			putAvg();
			putLp();
			putTp();
			//putTd();
			return (TCL_OK);
		}
	}
	// }else if(argc == 4) {
	// 	if (strcmp(argv[1], "getAvg") == 0) {
	// 		totalpkt();
	// 		return (TCL_OK);
	// 	}
	// }

	return (Queue::command(argc, argv));
}