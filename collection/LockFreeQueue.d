module pronghorn.collection.LockFreeQueue;

import core.atomic;

shared class LockFreeQueue(T)
{
    public this()
    {
        head = new Node();
        tail = head;
    }
    
    public void enqueue(T payload)
    {
        auto node = new Node();
        node.payload = payload;
        
        shared(Node)* oldTail;
        shared(Node)* oldNext;
        
        bool updated = false;
        
        
        while(!updated)
        {
            // make local copies of the tail and its Next link, but in 
            // getting the latter use the local copy of the tail since
            // another thread may have changed the value of tail
            oldTail = tail;
            oldNext = oldTail.next;
            
            // providing that the tail field has not changed...
            if(tail == oldTail)
            {
                // ...and its Next field is null
                if(oldNext == null)
                {
                    // ...try to update the tail's Next field
                    updated = cas!(shared(Node)*, Node*, Node*)(&tail.next, null, node);
                }
                // if the tail's Next field was non-null, another thread
                // is in the middle of enqueuing a new node, so try and 
                // advance the tail to point to its Next node
                else
                {
                    cas!(shared(Node)*, Node*, Node*)(&tail, oldTail, oldNext); 
                }
            
            }
        }
        
        // try and update the tail field to point to our node; don't
        // worry if we can't, another thread will update it for us on
        // the next call to enqueue()
        cas!(shared(Node)*, Node*, Node*)(&tail, oldTail, node);

        //atomicOp!("+=", size_t, size_t)(_count, 1);
    }
    
    public bool dequeue(ref T payload)
    {
        bool haveAdvancedHead = false;
        
        while(!haveAdvancedHead)
        {
            shared(Node)* oldHead = head;
            shared(Node)* oldTail = tail;
            shared(Node)* oldHeadNext = oldHead.next;
            
            if(oldHead == head)
            {
                // providing that the head field has not changed...
                if(oldHead == oldTail)
                {
                    // ...and it is equal to the tail field
                    if(oldHeadNext == null)
                    {
                        return false;
                    }
                    
                    // if the head's Next field is non-null and head was equal to the tail
                    // then we have a lagging tail: try and update it
                    cas!(shared(Node)*, Node*, Node*)(&tail, oldTail, oldHeadNext);
                }
                // otherwise the head and tail fields are different
                else
                {
                    // grab the item to dequeue, and then try to advance the head reference
                    payload = oldHeadNext.payload;
                    haveAdvancedHead = cas!(shared(Node)*, Node*, Node*)(&head, oldHead, oldHeadNext);
                    
                    //atomicOp!("-=", size_t, size_t)(_count, 1);
                }
                    

            }
        }
        
        return true;
    }
    
    /*
    @property
    public size_t count()
    {
        return _count;
    }
    */
    
    shared final private struct Node
    {
        T payload;
        Node* next;
    }
    
    private Node* head;
    private Node* tail;
    //private size_t _count;
    
}