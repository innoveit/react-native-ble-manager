package it.innove;

import java.nio.ByteBuffer;

public class NotifyBufferContainer {
    public ByteBuffer items;

    public NotifyBufferContainer(int size) {
        this.items = ByteBuffer.allocate(size);
    }
    public void resetBuffer(){
        this.items.clear();
    }
    public byte[] put(byte[] value){
        int restLength = value.length - this.items.remaining();
        byte[] toInsert = null;
        byte[] rest = null;
        if (restLength < 0) {
            rest = new byte[restLength];
            toInsert = new byte[value.length - restLength];
            System.arraycopy(value, 0, toInsert, 0, toInsert.length);
            System.arraycopy(value, toInsert.length, rest, restLength, rest.length);
        } else {
            toInsert = value;
        }
        this.items.put(toInsert);
        return rest;
    }
    public boolean isBufferFull(){
        return this.items.remaining() == 0;
    }
    public int size() {
        return this.items.limit();
    }
    @Override 
    protected void finalize() throws Throwable {
        this.items = ByteBuffer.allocate(0);
    }
}
