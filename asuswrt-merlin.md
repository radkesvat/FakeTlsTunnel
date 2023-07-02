# مقدمه
در این آموزش یادتون میدم چطور این ابزار رو برای روترهای ایسوس بیلد کنید  
# چرا؟
با استفاده از سرور ایران کیفیت خوبی نمیگرفتم اما به صورت مستقیم کیفیت کانکشن به مراتب بهتر بود  
# مشکل؟
یه شبکه خانگی را تصور کنید، دستگاه های مختلفی در این شبکه هستند، از جمله لپ تاپ، گوشی، تلویزیون هوشمند و دیگر دیوایس ها  
این یک ابزار واسط میباشد که میان کلاینت شما و سرور قرار میگیرد، بنابراین قبل از استارت کلاینت باید تانل را اجرا کنید که همین عمل یک لایه پیچیدگی ایجاد میکند و حتی ممکن است اجرای آن روی دستگاه هایی از جمله تلویزیون هوشمند تقریبا غیرممکن باشد
# ایده؟
به جای استارت کردن تانل روی دستگاه های مختلف یکبار روی روتر اجرا میکنم و به این صورت روتر مانند سرور ایران عمل میکند
# پیشنیازها
- روتر ایسوس با فریمور بروز
- فلش مموری
- آشنایی نسبی با ترمینال
- صبر به مقادیر خیلی زیاد
# روتر تست شده
[**Asus ROG Rapture GT-AX6000**](https://rog.asus.com/us/networking/rog-rapture-gt-ax6000-model)
# فعال کردن ssh
به صورت پیش فرض فعال نیست و باید از تنظیمات فعالش کنید
# Asuswrt-Merlin
ابتدا باید این فریمور کاستوم رو روی روتر نصب کنید  
وارد سایت رسمیش بشید  
[**Asuswrt-Merlin**](https://www.asuswrt-merlin.net)  
مدل روتر خودتون رو پیدا کنید و آخرین ورژن پایدار ریلیز شده رو دانلود و نصب کنید  
روند نصبش اصلا سخت نیست و از طریق پنل مدیریت وب روتر انجام میشه  
فایل فشرده دانلود شده رو اکسترکت کنید  
اکستنشن فایل فریمور  
kgtb  
وارد مسیر  
Administration > Firmware Upgrade  
بشید و از گزینه آپلود فایل رو انتخاب کنید، صبر کنید نصب تمام شود
# Entware
خوب ما قرار است این ابزار رو روی خود روتر بیلد کنیم!! پس به کلی ابزار نیاز داریم، خبر بد اینه که ابزارهای روتر حتی با فریمور کاستوم مرلین به شدت محدود هست  
اما خبر خوب  
[**Entware/Entware**](https://github.com/Entware/Entware)  
هست که یه رپو خیلی خفنه شامل کلی ابزار کاربردی برای دستگاه های امبدد  
برای نصبش شما به فلش مموری نیاز دارید که حتما هم باید فرمت  
ext4  
داشته باشه  
# چطوری نصبش کنیم؟
فلش مموری رو به روتر وصل کنید و کامندهای زیر رو بزنید  
```bash
ssh admin@192.168.50.1
wget https://raw.githubusercontent.com/RMerl/asuswrt-merlin.ng/a46283c8cbf2cdd62d8bda231c7a79f5a2d3b889/release/src/router/others/entware-setup.sh
chmod +x entware-setup.sh
./entware-setup.sh
```
بعد از نصب بهتره یه ریبوت انجام بدید  
```bash
reboot
```
این آموزش خیلی خلاصه بود  
آموزش مفصل نصبش در اینجا گفته شده  
[**Setup Entware on Asuswrt-merlin**](https://gist.github.com/1951FDG/3cada1211df8a59a95a8a71db6310299)  
در صورتی که نصب درست انجام شده باشه روی فلش یه فولدر باید ایجاد شده باشه با نام  
entware  
که این فولدر به مسیر  
`/opt`  
لینک شده  
لیست ابزارهای موجود  
[**aarch64-k3.10**](https://bin.entware.net/aarch64-k3.10)  
که شامل آخرین ورژن ها هست و در صورت انتشار ورژن جدید نسخه قبلی را در این مسیر میتوانید پیدا کنید  
[**aarch64-k3.10/archive**](https://bin.entware.net/aarch64-k3.10/archive)  
# نصب ابزارهای مورد نیاز
خوب شما الان یک پکیج منیجر دارید با نام  
opkg  
برای نصب یک پکیج بهتره ابتدا اون رو دانلود و سپس نصب کنید  
```bash
wget https://bin.entware.net/aarch64-k3.10/tar_1.34-4_aarch64-3.10.ipk
wget https://bin.entware.net/aarch64-k3.10/openssl-util_3.0.8-9_aarch64-3.10.ipk
wget https://bin.entware.net/aarch64-k3.10/curl_8.1.1-1_aarch64-3.10.ipk
wget https://bin.entware.net/aarch64-k3.10/git_2.39.2-1_aarch64-3.10.ipk
wget https://bin.entware.net/aarch64-k3.10/gcc_8.4.0-5b_aarch64-3.10.ipk
wget https://bin.entware.net/aarch64-k3.10/screen_4.8.0-2_aarch64-3.10.ipk
```
ممکنه ورژن جدید منتشر شده باشه و کار نکن لینک ها که میتونید به لیست مراجعه کنید و لینک درست رو بزنید  
حالا نصب کنید  
```bash
opkg install tar_1.34-4_aarch64-3.10.ipk
opkg install openssl-util_3.0.8-9_aarch64-3.10.ipk
opkg install curl_8.1.1-1_aarch64-3.10.ipk
opkg install git_2.39.2-1_aarch64-3.10.ipk
opkg install gcc_8.4.0-5b_aarch64-3.10.ipk
opkg install screen_4.8.0-2_aarch64-3.10.ipk
```
# Nim compiler
یک ابزار دیگه مونده برای نصب  
رپوی بیلد این کامپایلر در اینجا موجود هست  
[**nim-lang/nightlies**](https://github.com/nim-lang/nightlies/releases)  
```bash
wget https://github.com/nim-lang/nightlies/releases/download/latest-version-1-6/linux_arm64.tar.xz
/opt/bin/tar -xvf linux_arm64.tar.xz
```
فولدر اون رو به یک مکان مناسب منتقل کنید، مثلا  
```bash
mv nim /opt/usr/bin
```
و سپس به متغییر سیستمی آدرس اضافه کنید  
```bash
export PATH="$PATH:/opt/usr/bin/nim/bin"
```
# Github ssh key
برای کلون کردن پروژه ابتدا باید یک کلید بسازید  
```bash
dropbearkey -t rsa -f github
```
هنگام ساخت کلید عمومی رو چاپ میکنه که باید کپی کنید و به گیت هاب اضافه کنید
# Clone repo
پروژه رو کلون کنید و وارد اون بشید  
```bash
GIT_SSH_COMMAND='ssh -i /absolute/github -o IdentitiesOnly=yes' git clone git@github.com:radkesvat/FakeTlsTunnel.git
cd FakeTlsTunnel
```

# Build
میرسم به غول مرحله آخر یعنی بیلد کردن ولی قبل از هر چیزی باید یک سوئیچ به تسک بیلد اضافه کنید  
```bash
nano config.nims
# task build_server:
# switch("define", "nimNoGetRandom")
```
حالا میتونید بیلد کنید
```bash
nim build
```
اگر مراحل رو درست انجام داده باشید بیلد باید بدون خطا انجام بشه و سپس در فولدر
dist  
فایل اجرا آماده استفاده میشه
# Screen
برای اینکه بتونید تونل اجرا کنید ولی ترمینال رو ببنید از اسکرین استفاده میکنیم  
```bash
screen -S ftt
nohup /absoulte/FTT ... > /dev/null &
```
برای خروج از این سشن کلیدهای ترکیبی  
Ctrl+A, D  
رو میزنید، برای دیدن لیست سشن ها
```bash
screen -ls
```
و برای بازگشت به سشن  
```bash
screen -r ftt
```
# سخن پایانی
امیدوارم از این آموزش لذت برده باشید  
موارد خیلی زیاد بودند و واقعا نمیشد مفصل توضیح داد  
مطالبی که مطالعه کردید خلاصه و چکیده یک هفته سر و کله زدن اینجانب  
[**Saeed-Pooyanfar**](http://github.com/Saeed-Pooyanfar)  
با روتر و ابزارهای مختلف بود  
در آخر تشکر میکنم از توسعه دهنده اصلی  
[**radkesvat**](https://github.com/radkesvat)  
بابت این ابزار بسیار کاربردی  
به امید رفع محدودیت ها و دسترسی همیشگی به اینترنت آزاد
