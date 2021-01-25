<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Bag;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Bag\CanBeFetchedBag;
use VPNMinute\Core\Bag\CanStoreObjectCollection;
use VPNMinute\Core\CanBeFetched;

class CanBeFetchedBagSpec extends ObjectBehavior
{
    public function let(CanBeFetched $obj1, CanBeFetched $obj2)
    {
        $obj1->getName()->willReturn('foo');
        $obj2->getName()->willReturn('bar');
    }

    public function it_is_initializable()
    {
        $this->shouldHaveType(CanBeFetchedBag::class);
    }

    public function it_is_a_can_store_object_collection()
    {
        $this->shouldImplement(CanStoreObjectCollection::class);
    }

    public function it_can_store_and_return_can_be_fetched_objects($obj1, $obj2)
    {
        $this->add($obj1);
        $this->add($obj2);

        $this->get('foo')->shouldReturn($obj1);
        $this->get('bar')->shouldReturn($obj2);

        $this->getAll()->shouldReturn(['foo' => $obj1, 'bar' => $obj2]);
    }

    public function it_should_return_whether_or_not_it_contains_an_object($obj1)
    {
        $this->add($obj1);

        $this->contain('foo')->shouldReturn(true);
        $this->contain('bar')->shouldReturn(false);
    }

    public function it_should_not_add_the_same_object_multiple_times($obj1)
    {
        $this->add($obj1);
        $this->add($obj1);
        $this->add($obj1);

        $this->getAll()->shouldReturn(['foo' => $obj1]);
    }

    public function it_returns_null_when_an_object_is_not_in_the_bag()
    {
        $this->get('baz')->shouldReturn(null);
    }
}
