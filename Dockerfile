# 使用多阶段构建的第一阶段，进行Maven构建
FROM maven:3.8.5-openjdk-17 AS build

# 设置工作目录
WORKDIR /build

# 复制项目文件
COPY pom.xml .
COPY src ./src

# 运行Maven构建，跳过单元测试以加快构建速度
RUN mvn clean package -DskipTests

# 使用多阶段构建的第二阶段，创建最终镜像
FROM eclipse-temurin:17-jre-alpine

ARG user=spring
ARG group=spring

ENV SPRING_HOME=/home/spring

# Alpine Linux 使用 addgroup 和 adduser 命令
RUN addgroup -g 1000 ${group} \
	&& adduser -D -h "$SPRING_HOME" -u 1000 -G ${group} -s /bin/sh ${user}

# 创建配置和日志目录
RUN mkdir -p $SPRING_HOME/config \
	&& mkdir -p $SPRING_HOME/logs \
	&& chown -R ${user}:${group} $SPRING_HOME/config $SPRING_HOME/logs

# 设置工作目录
WORKDIR $SPRING_HOME

# 从构建阶段复制打包好的jar文件到工作目录
COPY --from=build /build/target/midjourney-proxy-*.jar ./app.jar

# 暴露端口
EXPOSE 8080 9876

# 设置环境变量
ENV JAVA_OPTS="-XX:MaxRAMPercentage=85 -Djava.awt.headless=true -XX:+HeapDumpOnOutOfMemoryError \
 -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -Xlog:gc:file=$SPRING_HOME/logs/gc.log \
 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9876 -Dcom.sun.management.jmxremote.ssl=false \
 -Dcom.sun.management.jmxremote.authenticate=false -Dlogging.file.path=$SPRING_HOME/logs \
 -Dserver.port=8080 -Duser.timezone=Asia/Shanghai"

# 设置用户
USER ${user}

# 设置启动命令，使用Alpine默认的shell /bin/sh
ENTRYPOINT ["/bin/sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
