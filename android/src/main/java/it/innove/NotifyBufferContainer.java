package it.innove;

import java.nio.ByteBuffer;

public class NotifyBufferContainer {
    public final Integer maxBufferSize;
    private Integer bufferCount;
    public ByteBuffer items;

    public NotifyBufferContainer(Integer size) {
        this.maxBufferSize = size;
        this.resetBuffer();
    }
    public void resetBuffer(){
        this.bufferCount = 0;
        this.items = ByteBuffer.allocate(this.maxBufferSize);
    }
    public void put(byte[] value){
        this.bufferCount += value.length;
        if (this.items.remaining() < value.length) {
            return;
        }
        this.items.put(value);
    }
    public boolean isBufferFull(){
        return this.bufferCount >= this.maxBufferSize;
    }
    public Integer size() {
        return this.bufferCount;
    }
    @Override 
    protected void finalize() throws Throwable {
        this.items = ByteBuffer.allocate(0);
    }
}
