package it.innove;

import java.nio.ByteBuffer;

public class NotifyBufferContainer {
    public final String key;
    public final Integer maxCount;
    private Integer bufferCount;
    public ByteBuffer items;

    public NotifyBufferContainer(String key, Integer count) {

        this.key = key;
        this.maxCount = count;
        this.resetBuffer();
    }
    public void resetBuffer(){
        this.bufferCount =0;
        this.items = ByteBuffer.wrap(new byte[this.maxCount * 20]);
    }
    public void put(byte[] value){
        this.bufferCount +=1;
        this.items.put(value);
    }
    public Integer size(){
        return this.bufferCount;
    }
}
